$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Get-Module module | Remove-Module -Force
Import-Module (Join-Path $PSScriptRoot '..\Github-Helper.psm1' -Resolve)

Describe 'CreateReleaseNotes.ps1 Tests' {
    
    It 'Confirm right functions are called' {
        Mock GetLatestRelease { return @{tag_name = "1.0.0.0";} | ConvertTo-Json } 
        Mock GetReleaseNotes  {return "Mocked notes"}
    
        .  (Join-Path -path $here -ChildPath ".\CreateReleaseNotes.ps1" -Resolve) -token "" -actor "" -workflowToken "" -tag_name "1.0.0.5"
    
        Should -Invoke -CommandName GetLatestRelease -Exactly -Times 1 
        Should -Invoke -CommandName GetReleaseNotes -Exactly -Times 1 -ParameterFilter { $tag_name -eq "1.0.0.5" -and $previous_tag_name -eq "1.0.0.0" }

        $realseNotes | Should -Be "Mocked notes"
    }

    It 'Confirm right parameters are passed' {
        Mock GetLatestRelease { return "{}" | ConvertTo-Json } 
        Mock GetReleaseNotes  {return "Mocked notes"}
    
        .  (Join-Path -path $here -ChildPath ".\CreateReleaseNotes.ps1" -Resolve) -token "" -actor "" -workflowToken "" -tag_name "1.0.0.5"
    
        Should -Invoke -CommandName GetLatestRelease -Exactly -Times 1 
        Should -Invoke -CommandName GetReleaseNotes -Exactly -Times 1 -ParameterFilter { $tag_name -eq "1.0.0.5" -and $previous_tag_name -eq "" }

        $realseNotes | Should -Be "Mocked notes"
    }

    It 'Confirm when throws' {
        Mock GetLatestRelease { throw "Exception" } 
        Mock GetReleaseNotes  {return "Mocked notes"}
    
        .  (Join-Path -path $here -ChildPath ".\CreateReleaseNotes.ps1" -Resolve) -token "" -actor "" -workflowToken "" -tag_name "1.0.0.5"
    
        Should -Invoke -CommandName GetLatestRelease -Exactly -Times 1 

        $realseNotes | Should -Be ""
    }
}
