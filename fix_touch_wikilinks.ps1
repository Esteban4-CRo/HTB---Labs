$ErrorActionPreference = "Stop"

$filePath = "C:\Users\USUARIO\Desktop\HTB\01-Machines\Windows\Touch.md"
$content = [System.IO.File]::ReadAllText($mdFile.FullName, [System.Text.Encoding]::UTF8)
$originalContent = $content

# Patrón para wikilinks de Obsidian: ![texto](ruta) o [[ruta]]
# Aquí las imágenes están como: ![Texto](ruta) con ruta relativa ../../Images/touch/archivo.png
# También podrían ser [[ruta]]

$content = [regex]::Replace($content, '!\[([^\]]*)\]\((\.\./\.\./Images/[^)]+)\)', {
    param($match)
    $altText = $match.Groups[1].Value
    $fullPath = $match.Groups[2].Value
    
    # Extraer nombre de archivo
    $fileName = [System.IO.Path]::GetFileName($fullPath)
    
    # Nueva ruta correcta desde 01-Machines/Windows/
    $newUrl = "../../Images/touch/$fileName"
    $newUrl = $newUrl -replace ' ', '%20'
    
    return "![$altText]($newUrl)"
})

# También arreglar wikilinks de Obsidian [[archivo]]
$content = [regex]::Replace($content, '!\[\[([^\]]+)\]\]', {
    param($match)
    $fullPath = $match.Groups[1].Value
    
    # Extraer nombre de archivo
    $fileName = [System.IO.Path]::GetFileName($fullPath)
    
    # Nueva ruta
    $newUrl = "../../Images/touch/$fileName"
    $newUrl = $newUrl -replace ' ', '%20'
    
    return "![$fileName]($newUrl)"
})

if ($content -ne $originalContent) {
    [System.IO.File]::WriteAllText($mdFile.FullName, $content, [System.Text.Encoding]::UTF8)
    Write-Host "Actualizado: $($mdFile.Name)"
} else {
    Write-Host "Sin cambios: $($mdFile.Name)"
}

Write-Host "=== Listo ==="