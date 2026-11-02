$ErrorActionPreference = "Stop"

$filePath = "C:\Users\USUARIO\Desktop\HTB\01-Machines\Windows\Touch.md"
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
$originalContent = $content

# Patrón para wikilinks de Obsidian: ![[ruta]]
# Convierten a: ![texto](../../Images/touch/archivo.png)
$content = [regex]::Replace($content, '!\[([^\]]*)\]', {
    param($match)
    $fullPath = $match.Groups[1].Value
    
    # Extraer nombre de archivo
    $fileName = [System.IO.Path]::GetFileName($fullPath)
    
    # Nueva ruta desde 01-Machines/Windows/ a Images/touch/
    $newUrl = "../../Images/touch/$fileName"
    $newUrl = $newUrl -replace ' ', '%20'
    
    return "![$fileName]($newUrl)"
})

if ($content -ne $originalContent) {
    [System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
    Write-Host "Actualizado: $filePath"
} else {
    Write-Host "Sin cambios: $filePath"
}

Write-Host "=== Listo ==="