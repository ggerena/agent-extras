---
name: markitdown
description: Guía para convertir archivos a Markdown usando la utilidad markitdown (CLI y Python). Usar cuando el usuario necesite convertir documentos, imágenes, audio u otros archivos a formato Markdown.
argument-hint: [archivo o pregunta sobre markitdown]
---

# markitdown - Convertir archivos a Markdown

Herramienta de Microsoft para convertir archivos a Markdown, optimizada para consumo de LLMs.

## Formatos soportados

PDF, Word (.docx), PowerPoint (.pptx), Excel (.xlsx/.xls), imágenes (EXIF+OCR), audio (metadata+transcripción), HTML, CSV, JSON, XML, ZIP, YouTube URLs, EPubs, Outlook (.msg), Jupyter notebooks (.ipynb).

## CLI - Uso desde terminal

```bash
# Convertir archivo (output a stdout)
markitdown archivo.pdf

# Guardar a archivo
markitdown archivo.pdf -o resultado.md

# Desde pipe
cat archivo.pdf | markitdown

# Hint de extensión (cuando no tiene nombre)
markitdown -x .pdf < archivo_sin_extension

# Hint de MIME type
markitdown -m application/pdf archivo

# Azure Document Intelligence (mejor calidad PDFs complejos)
markitdown archivo.pdf -d -e "<endpoint_azure>"

# Plugins
markitdown --list-plugins
markitdown --use-plugins archivo.xyz

# Mantener data URIs en output
markitdown --keep-data-uris archivo.html
```

### Flags CLI

| Flag | Descripción |
|------|-------------|
| `-o` | Archivo de salida |
| `-x` | Extensión del archivo (hint) |
| `-m` | MIME type (hint) |
| `-c` | Charset (hint) |
| `-d` | Usar Azure Document Intelligence |
| `-e` | Endpoint de Azure Doc Intel |
| `-p` / `--use-plugins` | Habilitar plugins |
| `--list-plugins` | Listar plugins instalados |
| `--keep-data-uris` | No truncar data URIs |
| `-v` | Versión |

## Python API

```python
from markitdown import MarkItDown

md = MarkItDown()

# Convertir archivo local
result = md.convert("archivo.xlsx")
print(result.text_content)

# Convertir URL
result = md.convert("https://example.com/doc.pdf")

# Convertir stream binario
with open("archivo.pdf", "rb") as f:
    result = md.convert_stream(f)

# Con LLM para describir imágenes (pptx e imágenes)
from openai import OpenAI
client = OpenAI()
md = MarkItDown(llm_client=client, llm_model="gpt-4o")
result = md.convert("imagen.jpg")
```

### Métodos principales

| Método | Input |
|--------|-------|
| `convert(source)` | path, URL, Response, BinaryIO |
| `convert_local(path)` | archivo local |
| `convert_stream(stream)` | stream binario (BytesIO, NO StringIO) |
| `convert_uri(uri)` | http, https, file, data |

### Resultado

- `result.text_content` o `result.markdown` - contenido Markdown
- `result.title` - título del documento (si existe)

### Excepciones

- `UnsupportedFormatException` - formato no soportado
- `FileConversionException` - conversión falló
- `MissingDependencyException` - faltan dependencias opcionales

## Instalación (si no está instalado)

```bash
pip install 'markitdown[all]'          # todo
pip install 'markitdown[pdf,docx]'     # solo algunos formatos
```

Dependencias opcionales: `[all]`, `[pdf]`, `[docx]`, `[pptx]`, `[xlsx]`, `[xls]`, `[outlook]`, `[audio-transcription]`, `[youtube-transcription]`, `[az-doc-intel]`.

## Instrucciones

Cuando el usuario pida convertir un archivo a Markdown:

1. Si da un archivo específico, usar `markitdown` por CLI con el comando apropiado
2. Si necesita integración en Python, mostrar el código con la API
3. Si hay error de dependencias, sugerir instalar el grupo opcional correspondiente
4. Si el usuario pasa argumentos a `/markitdown`, interpretar como archivo a convertir:
   - Ejecutar: `markitdown $ARGUMENTS`
