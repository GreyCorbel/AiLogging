Param
(
    [Parameter(Mandatory)]    
    $version
)

#credit goes to Joel Bennett for https://gist.github.com/Jaykul/0031bbb459c1ab6ced2bde7558130ede
Function Update-Manifest
{
    param
    (
        
        [Parameter(Mandatory)]
        $ManifestFile,
        [Parameter(Mandatory)]
        $AttributeName,
        [Parameter(Mandatory)]
        $AttributeValue
    )

    process
    {
        $Tokens = $Null; $ParseErrors = $Null
        $ManifestContent = Get-Content $manifestFile -Raw
        $AST = [System.Management.Automation.Language.Parser]::ParseInput( $ManifestContent, $ManifestFile, [ref]$Tokens, [ref]$ParseErrors )
        $ManifestHash = $AST.Find( {$args[0] -is [System.Management.Automation.Language.HashtableAst]}, $true )
        $keyValue = $ManifestHash.KeyValuePairs.Where{$_.Item1.Value -eq $AttributeName}.Item2

        while($KeyValue.parent) { $KeyValue = $KeyValue.parent }

        $ManifestContent = $KeyValue.Extent.Text.Remove($extent.StartOffset, ($extent.EndOffset - $extent.StartOffset)).Insert($extent.StartOffset,$AttributeValue)
        Set-Content $manifestFile $ManifestContent
    }
}

#write version to module manifest
Update-Manifest -ManifestFile .\AiLogging.psd1 -AttributeName ModuleVersion -AttributeValue "'$version'"
#stage changes in manifest
git add .\AiLogging.psd1
#commit changes manifest
git commit -m "Version $version for publishing on PSGallery"
git push origin
#create a version tag that triggers CI
git tag "v$version" -a -m "Version $version for publishing on PSGallery"
#push changes
git push origin --tags
