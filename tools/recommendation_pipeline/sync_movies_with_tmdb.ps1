param(
    [string]$BaseUrl = "http://127.0.0.1:8090",
    [string]$PublicBaseUrl = "http://10.0.2.2:8090",
    [Parameter(Mandatory = $true)]
    [string]$SuperuserEmail,
    [Parameter(Mandatory = $true)]
    [string]$SuperuserPassword,
    [string]$TmdbToken = $env:TMDB_BEARER_TOKEN,
    [string]$DatasetDir = ".\assets\db\ml-latest-small",
    [string]$InputFile = ".\assets\db\movies_seed.json",
    [string]$OutputFile = ".\assets\db\movies_enriched.json",
    [int]$Limit = 200,
    [string]$Language = "ru-RU",
    [switch]$MirrorPosters = $true
)

if ([string]::IsNullOrWhiteSpace($TmdbToken)) {
    throw "TMDB token is required. Pass -TmdbToken or set TMDB_BEARER_TOKEN."
}

$ErrorActionPreference = "Stop"

Write-Host "Step 1/2: Enriching movies with TMDB metadata..."
python .\tools\recommendation_pipeline\enrich_movies_with_tmdb.py `
    --dataset-dir $DatasetDir `
    --input-file $InputFile `
    --tmdb-token $TmdbToken `
    --output-file $OutputFile `
    --limit $Limit `
    --language $Language

if ($LASTEXITCODE -ne 0) {
    throw "TMDB enrichment failed."
}

Write-Host "Step 2/2: Importing enriched movies into PocketBase..."
python .\tools\recommendation_pipeline\pocketbase_import_json.py `
    --base-url $BaseUrl `
    --superuser-email $SuperuserEmail `
    --superuser-password $SuperuserPassword `
    --collection movies `
    --json-file $OutputFile `
    --lookup-template 'movieId={movieId}'

if ($LASTEXITCODE -ne 0) {
    throw "PocketBase import failed."
}

if ($MirrorPosters) {
    Write-Host "Step 3/3: Mirroring posters into PocketBase media..."
    python .\tools\recommendation_pipeline\mirror_movie_posters_to_pocketbase.py `
        --base-url $BaseUrl `
        --public-base-url $PublicBaseUrl `
        --superuser-email $SuperuserEmail `
        --superuser-password $SuperuserPassword `
        --limit $Limit

    if ($LASTEXITCODE -ne 0) {
        throw "Poster mirroring failed."
    }
}

Write-Host "Done. Open the Movies screen and pull to refresh."
