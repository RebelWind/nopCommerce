# create the build instance 
FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS build

WORKDIR /src                                                                    
COPY ./src ./

# build solution   
RUN dotnet build NopCommerce.sln --no-incremental -c Release

# publish project
WORKDIR /src/Presentation/Nop.Web   
RUN dotnet publish Nop.Web.csproj -c Release -o /app/published

WORKDIR /app/published

RUN mkdir logs bin

RUN chmod 775 App_Data \
              App_Data/DataProtectionKeys \
              bin \
              logs \
              Plugins \
              wwwroot/bundles \
              wwwroot/db_backups \
              wwwroot/files/exportimport \
              wwwroot/icons \
              wwwroot/images \
              wwwroot/images/thumbs \
              wwwroot/images/uploaded \
              wwwroot/sitemaps

# create the runtime instance 
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime 

# add globalization support
RUN apk add --no-cache icu-libs icu-data-full
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# installs required packages
RUN apk add tiff --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/main/ --allow-untrusted
RUN apk add libgdiplus --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community/ --allow-untrusted
RUN apk add libc-dev tzdata curl bash --no-cache

# OpenTelemetry kurulumu
RUN curl -sSfL https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/latest/download/otel-dotnet-auto-install.sh -o /tmp/otel-dotnet-auto-install.sh && \
    chmod +x /tmp/otel-dotnet-auto-install.sh && \
    bash /tmp/otel-dotnet-auto-install.sh && \
    chmod +x $HOME/.otel-dotnet-auto/instrument.sh && \
    mkdir -p /otel-dotnet && \
    cp -r $HOME/.otel-dotnet-auto/* /otel-dotnet/ && \
    chmod -R 755 /otel-dotnet/ && \
    rm /tmp/otel-dotnet-auto-install.sh

# copy entrypoint script
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

WORKDIR /app

COPY --from=build /app/published .

ENV ASPNETCORE_URLS=http://+:80
# OpenTelemetry ortam değişkenleri
ENV CORECLR_ENABLE_PROFILING="1"
ENV CORECLR_PROFILER="{918728DD-259F-4A6A-AC2B-B85E1B658318}"
ENV CORECLR_PROFILER_PATH="/otel-dotnet/linux-x64/OpenTelemetry.AutoInstrumentation.Native.so"
ENV DOTNET_ADDITIONAL_DEPS="/otel-dotnet/AdditionalDeps"
ENV DOTNET_SHARED_STORE="/otel-dotnet/store"
ENV DOTNET_STARTUP_HOOKS="/otel-dotnet/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll"
ENV OTEL_DOTNET_AUTO_HOME="/otel-dotnet"
ENV OTEL_TRACES_EXPORTER="otlp"
ENV OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
ENV OTEL_SERVICE_NAME="nopcommerce"

EXPOSE 80
                            
ENTRYPOINT "/entrypoint.sh"
