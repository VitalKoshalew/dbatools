$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandPath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $paramCount = 7
        $defaultParamCount = 13
        [object[]]$params = (Get-ChildItem function:\Sync-DbaLoginPermission).Parameters.Keys
        $knownParameters = 'Source','SourceSqlCredential','Destination','DestinationSqlCredential','Login','ExcludeLogin','EnableException'
        It "Should contain our specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$CommandName Integration Tests" -Tag "IntegrationTests" {
    BeforeAll{
        $tempguid = [guid]::newguid();
        $DBUserName = "dbatoolssci_$($tempguid.guid)"
$CreateTestUser = @"
CREATE LOGIN [$DBUserName]
    WITH PASSWORD = '$($tempguid.guid)';
USE Master;
CREATE USER [$DBUserName] FOR LOGIN [$DBUserName]
    WITH DEFAULT_SCHEMA = dbo;
GRANT VIEW ANY DEFINITION to [$DBUserName];
"@
        Invoke-DbaQuery -SqlInstance $script:instance2 -Query $CreateTestUser -Database master

#This is used later in the test
$CreateTestLogin = @"
CREATE LOGIN [$DBUserName]
    WITH PASSWORD = '$($tempguid.guid)';
"@
    }
    AfterAll{
        $DropTestUser = "DROP LOGIN [$DBUserName]"
        Invoke-DbaQuery -SqlInstance $script:instance2,$script:instance3 -Query $DropTestUser -Database master
    }

    Context "Verifying command output" {

        It "Should not have the user permissions of $DBUserName" {
            $permissionsBefore = Get-DbaUserPermission -SqlInstance $script:instance3 -Database master | Where-object {$_.member -eq $DBUserName}
            $permissionsBefore | Should -be $null
        }

        It "Should execute against active nodes" {
            #Creates the user on
            Invoke-DbaQuery -SqlInstance $script:instance3 -Query $CreateTestLogin
            $results = Sync-DbaLoginPermission -Source $script:instance2 -Destination $script:instance3 -Login $DBUserName -ExcludeLogin 'NotaLogin' -Warningvariable $warn
            $results | Should -be $null
            $warn | Should -be $null
        }

        It "Should have coppied the user permissions of $DBUserName" {
            $permissionsAfter = Get-DbaUserPermission -SqlInstance $script:instance3 -Database master | Where-object {$_.member -eq $DBUserName -and $_.permission -eq 'VIEW ANY DEFINITION' }
            $permissionsAfter.member | Should -Be $DBUserName
        }
    }
}
