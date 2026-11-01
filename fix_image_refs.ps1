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
        # Patrón: ![texto](../../Images/archivo.png) donde archivo NO empieza con el nombre de la máquina ya
        $pattern = '!\[([^\]]*)\]\((\.\./\.\./Images/)(?!' + $machineFolder + '/)(?!_shared/)(?!_unused/)([^)]+)\)'
        $content = [regex]::Replace($content, $pattern, {
            param($match)
            $altText = $match.Groups[1].Value
            $fileName = $match.Groups[3].Value
            return "![$altText]('../../Images/$machineFolder/$fileName')"
        })
    }
    
    if ($content -ne $originalContent) {
        [System.IO.File]::WriteAllText($mdFile.FullName, $content, [System.Text.Encoding]::UTF8)
        Write-Host "Actualizado: $($mdFile.Name)"
    }
}

Write-Host "=== Rutas de imagen actualizadas ==="