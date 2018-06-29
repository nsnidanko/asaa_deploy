# Author: Naz Snidanko
# Date Created: Jun 7, 2018
# Date Modified: 
# Version: 1.0
# Description: ASAA operations for Hyalto lab env.

# Create a listener on port 8080
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:8000/') 
$listener.Start()
'Listening ...'
# Run until you send a GET request to /end
while ($true) {
    $context = $listener.GetContext() 
 
    # Capture the details about the request
    $request = $context.Request
 
    # Setup a place to deliver a response
    $response = $context.Response
   
    # Break from loop if GET request sent to /end
    if ($request.Url -match '/end$') { 
        break 
    } else {
         
        # Split request URL to get command and options
        $requestvars = ([String]$request.Url).split("/");        
        
		#random number for job ID
		$jobid = Get-Random
		
		# If a request is sent to http://:8000/deploy
        if ($requestvars[3] -eq "deploy") {
 
		$platform = $requestvars[4]
		$name = $requestvars[5]
		
		Start-Job -Name $jobid -ScriptBlock {\opt\asaa_deploy\apideploy.ps1 -platform $args[0] -name $args[1] } -ArgumentList $platform, $name, $PsScriptRoot
		$message = "ASAA update for $name started. JobID is $jobid. You will be notified in Slack once completed ";
        $response.ContentType = 'text/html';
       } 
	   
	   elseif ($requestvars[3] -eq "update") {
		
		$platform = $requestvars[4]
		$version = $requestvars[5]
		
		Start-Job -Name $jobid -ScriptBlock {\opt\asaa_deploy\apiupdate.ps1 -platform $args[0] -version $args[1] } -ArgumentList $platform, $version
		$message = "ASAA update for $platform to $version started. JobID is $jobid. You will be notified in Slack once completed ";
        $response.ContentType = 'text/html';
	   
	   }
	   
	   elseif ($requestvars[3] -eq "status") {
		
		$jobname = $requestvars[4]
		
		$strStatus = Get-Job -Name $jobname
		$message = "$strStatus.State";
        $response.ContentType = 'text/html';
	   
	   }
	   
	   
	   else {
 
            # If no matching subdirectory/route is found generate a 404 message
            $message = "This is not the page you're looking for.";
            $response.ContentType = 'text/html' ;
       }
 
       # Convert the data to UTF8 bytes
       [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($message)
       
       # Set length of response
       $response.ContentLength64 = $buffer.length
	   
       # Write response out and close
       $output = $response.OutputStream
       $output.Write($buffer, 0, $buffer.length)
       $output.Close()
   }    
}
 
#Terminate the listener
$listener.Stop()