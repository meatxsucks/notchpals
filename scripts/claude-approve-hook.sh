#!/bin/bash
# Hook PermissionRequest de Claude Code: pide la aprobación en el notch (NotchPals).
# Si NotchPals no está abierto, no imprime nada y Claude Code sigue su flujo normal.
TOKEN_FILE="$HOME/.notchpals/token"
[ -f "$TOKEN_FILE" ] || exit 0
curl -s --max-time 110 -X POST "http://127.0.0.1:47600/approve" \
  -H "x-notchpals-token: $(cat "$TOKEN_FILE")" \
  -H "content-type: application/json" \
  --data-binary @- || exit 0
