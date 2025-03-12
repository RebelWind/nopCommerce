#!/bin/bash
set -e

# Alpine Linux için dinamik bağlayıcı sembolik bağlantısı oluştur
ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2

# OpenTelemetry instrument.sh betiğini çalıştır
if [ -f "/root/.otel-dotnet-auto/instrument.sh" ]; then
    echo "OpenTelemetry instrument.sh betiğini çalıştırıyorum..."
    source /root/.otel-dotnet-auto/instrument.sh
    echo "OpenTelemetry ortam değişkenleri:"
    env | grep OTEL
    env | grep DOTNET
fi

# Uygulamayı başlat
exec dotnet Nop.Web.dll
