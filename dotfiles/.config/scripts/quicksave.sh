#!/bin/bash

snapper -c root create --description "quicksave"  --cleanup-algorithm number
snapper -c root cleanup number
snapper -c home create --description "quicksave" --cleanup-algorithm number
snapper -c home cleanup number
notify-send "Quicksaved."
