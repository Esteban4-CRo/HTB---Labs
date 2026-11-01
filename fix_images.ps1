$ErrorActionPreference = "Stop"

$machineMap = @{
    "Reactor" = "Reactor";
    "TwoMillion" = "TwoMillion";
    "Appoinment" = "Appoinment";
    "Fireflow" = "Fireflow";
    "Sequel" = "Sequel";
    "Orion" = "Orion";
    "Odyssey" = "Odyssey";
    "MakeSense" = "MakeSense";
    "Layover" = "Layover";
    "Stream" = "Stream";
    "DutyBound" = "DutyBound";
    "DanglingTree" = "DanglingTree";
    "Cocodrile" = "Cocodrile";
    "Bedside" = "Bedside";
    "Touch" = "Touch"
}

$files = Get-ChildItem -Recurse -Filter "*.md" -Path "01-Machines/"
foreach ($mdFile in $files) {
    $content = [System.IO.File]::ReadAllText($mdFile.FullName, [System.Text.Encoding]::UTF8)
    $originalContent = $content
    
    foreach ($machineName in $machineMap.Keys) {
        $machineFolder = $machineMap[$machineName]
        $pattern = '!\[([^\]]*)\]\((\.\./\.\./Images/)([^)]+)\)'
        $content = [regex]::Replace($content, $pattern, {
            param($match)
            $altText = $match.Groups[1].Value
            $fullPath = $match.Groups[2].Value + $match.Groups[3].Value
            
            if ($fullPath -like "../../Images/$machineFolder/*") {
                return $match.Value
            }
            
            if ($fullPath -like "../../Images/_shared/*" -or $fullPath -like "../../Images/_unused/*") {
                return $match.Value
            }
            
            $fileName = [System.IO.Path]::GetFileName($fullPath)
            $resultString = '![{0}](../../Images/{1}/{2})' -f $altText, $machineFolder, $fileName
            return $resultString
        })
    }
    
    if ($content -ne $originalContent) {
        [System.IO.File]::WriteAllText($mdFile.FullName, $content, [System.Text.Encoding]::UTF8)
        Write-Host "Actualizado: $($mdFile.Name)"
    }
}

Write-Host "=== Rutas de imagen actualizadas ==="