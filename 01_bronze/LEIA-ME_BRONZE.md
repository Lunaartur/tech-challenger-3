# Camada Bronze

A ingestão utilizada neste projeto foi o upload manual dos três CSVs originais no Amazon S3, sem alterações nos arquivos. Portanto, não existe um Job Glue exclusivo para carregar a Bronze neste pacote.

Bucket: tech-challenge-fase3-grupo-18
Prefixo: bronze/dados-mercado-brasil/
Edições: 2023-2024, 2024-2025 e 2025-2026.

Mantenha os arquivos nos caminhos esperados pelo Job 01. O script que lê a Bronze e produz a primeira Silver está em ../02_silver/01_bronze_para_silver.py.

Este pacote inclui código e consultas; não inclui os CSVs originais nem uma cópia dos dados S3.
