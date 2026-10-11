D=$(cat $S/n08dir.txt); ls -la "$D" "$D/bin" 2>&1 | sed "s|$D|\$D|g"; find "$D" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sed "s|$D|\$D|g" | sort > $S/n08-before.txt; wc -l < $S/n08-before.txt; echo "$PATH" | tr ":" "
" | grep -c "$D"
