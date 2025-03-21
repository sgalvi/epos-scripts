#!/bin/bash 

# Funzione per mostrare l'uso dello script
usage() {
    echo "Uso: $0 -web <rete> [-y <anno>] [-dl <doy_inizio> <doy_fine>] [-s <sito>]"
    echo "  -web: rete obbligatoria (frednet, fvg, slo, aust)"
    echo "  -y: anno (default: anno corrente)"
    echo "  -dl: range di DOY (Day of Year) da processare"
    echo "  -s: sito specifico (default: tutti i siti)"
    echo "  --launch: lancia automaticamente process_rinex.sh dopo la generazione della lista"
    echo "  --lastweek: lancia il comando impostando la data di 7 giorni fa"
    exit 1
}

# Inizializzazione delle variabili
web=""
year=$(date -d "2 DAYS AGO" +%Y)
doy_start=$(date -d "2 DAYS AGO" +%j )
doy_end=$doy_start
site=""
launch=false
lastweek=false

# Parsing degli argomenti
while [[ $# -gt 0 ]]; do
    case $1 in
        -web) web=$2; shift 2 ;;
        -y) year=$2; shift 2 ;;
        -dl) doy_start=$2; doy_end=$3; shift 3 ;;
        -s) site=${2^^}; shift 2 ;; 
        --launch) launch=true; shift ;;
        --lastweek) lastweek=true; shift ;;
        *) usage ;;
    esac
done

if $lastweek; then
	year=$(date -d "7 DAYS AGO" +%Y)
	doy_start=$(date -d "7 DAYS AGO" +%j )
	doy_end=$doy_start
fi
doy_start=$(echo "$doy_start" | awk '{print $1 + 0}')
doy_end=$(echo "$doy_end" | awk '{print $1 + 0}')

# Verifica che la rete sia specificata
if [ -z "$web" ]; then
    echo "Errore: La rete (-web) è obbligatoria."
    usage
fi

# Mappa delle reti ai percorsi
declare -A network_paths
network_paths[frednet]="/mnt/frednet-rinex"
network_paths[fvg]="/mnt/fvg-rinex"
network_paths[slo]="/mnt/slo-rinex"
network_paths[aust]="/mnt/aus-rinex"

# Verifica che la rete specificata sia valida
if [ -z "${network_paths[$web]}" ]; then
    echo "Errore: Rete non valida. Usare frednet, fvg, slo o aust."
    exit 1
fi

# Funzione per generare la lista dei file
generate_file_list() {
    local base_path=${network_paths[$web]}
    local output_file="/home/crs/lists/${web}/${web}from${year}${doy_start}to${year}${doy_end}"

    if [ -n "$site" ]; then
        output_file="${output_file}${site}.lst"
    else
        output_file="${output_file}.lst"
    fi

    # Creazione della directory se non esiste
    mkdir -p "/home/crs/lists/${web}"

    for ((doy=doy_start; doy<=doy_end; doy++)); do
        doy_padded=$(printf "%03d" $doy)
        dir_path="$base_path/$year/$doy_padded"

        if [ -d "$dir_path" ]; then
            if [ -z "$site" ]; then
                find "$dir_path" -maxdepth 1 -name "*1D_30S_MO.crx.gz" >> "$output_file"
                find "$dir_path" -maxdepth 1 -name "???????0.*d*" >> "$output_file"
            else
                find "$dir_path" -maxdepth 1 -name "${site}*1D_30S_MO.crx.gz" >> "$output_file"
                find "$dir_path" -maxdepth 1 -name "${site,,}???0.*d*" >> "$output_file"
            fi
        else
	        echo "Directory non trovata: $dir_path"
	fi
    done

    echo "Lista creata in $output_file"

    # Se --launch è stato specificato, esegui ixqc_launch_file
    if $launch; then
        if [ -f "/home/crs/scripts/ixqc_launch_file" ]; then
            echo "Lanciando ixqc_launch_file..."
            /home/crs/scripts/ixqc_launch_file -l "$output_file" -w "$web"
        else
            echo "Errore: ixqc_launch_file non trovato nella directory corrente."
            exit 1
        fi
    fi
}

# Esecuzione della funzione principale
generate_file_list
