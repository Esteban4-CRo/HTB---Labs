$ErrorActionPreference = "Stop"

# Mapeo de máquina (nombre del archivo .md sin extensión) -> carpeta de imágenes
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
    $machineName = $mdFile.BaseName
    $content = [System.IO.File]::ReadAllText($mdFile.FullName, [System.Text.Encoding]::UTF8)
    $originalContent = $content
    
    # Determinar la carpeta de imágenes para esta máquina
    $machineFolder = $machineMap[$machineName]
    if (-not $machineFolder) {
        Write-Host "ADVERTENCIA: No hay mapeo para $machineName" -ForegroundColor Yellow
        continue
    }
    
    # Patrón: ![texto](ruta) donde ruta empieza con ../../Images/
    $pattern = '!\[([^\]]*)\]\((\.\./\.\./Images/[^)]+)\)'
    
    $content = [regex]::Replace($content, $pattern, {
        param($match)
        $altText = $match.Groups[1].Value
        $fullPath = $match.Groups[2].Value
        
        # Extraer solo el nombre del archivo
        $fileName = [System.IO.Path]::GetFileName($fullPath)
        
        # Retornar la nueva ruta
        return "![$altText]('../../Images/$machineFolder/$fileName')"
    })
    
    if ($content -ne $originalContent) {
        [System.IO.File]::WriteAllText($mdFile.FullName, $content, [System.Text.Encoding]::UTF8)
        Write-Host "Actualizado: $($mdFile.Name)"
    }
}

Write-Host "=== Rutas de imagen corregidas ==="