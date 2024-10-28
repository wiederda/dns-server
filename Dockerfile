# Use the .NET SDK as the base image
# https://mcr.microsoft.com/en-us/artifact/mar/dotnet/aspnet/tags
FROM mcr.microsoft.com/dotnet/aspnet:8.0.10-jammy-amd64 as base

# Use the .NET SDK to build the application
# https://mcr.microsoft.com/en-us/artifact/mar/dotnet/sdk/tags
FROM mcr.microsoft.com/dotnet/sdk:8.0.403-jammy-amd64 as build
RUN apt-get update && apt-get install -y git
WORKDIR /home/download

# Clone the repositories and build the projects
RUN git clone --depth 1 https://github.com/TechnitiumSoftware/TechnitiumLibrary.git \
    && git clone --depth 1 https://github.com/TechnitiumSoftware/DnsServer.git \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.ByteTree/TechnitiumLibrary.ByteTree.csproj -c Release \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.Net/TechnitiumLibrary.Net.csproj -c Release \
    && dotnet publish DnsServer/DnsServerApp/DnsServerApp.csproj -c Release -o /publish

# Use the base image for the final stage
FROM base as final
RUN apt-get update \
&& apt install curl -y \
&& apt install dnsutils -y 
#RUN apt install libmsquic -y

RUN mkdir -p /opt/technitium/dns
WORKDIR /opt/technitium/dns/

# Set up directories and install additional packages
RUN curl https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb --output packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \ 
    && apt-get install -y dotnet-runtime-8.0 \
    && apt-get remove curl -y \
    && apt-get clean -y

# Copy the published files from the build stage
COPY --from=build /publish /opt/technitium/dns
COPY --from=build /home/download/DnsServer/DnsServerApp/systemd.service /etc/systemd/system/dns.service

# Set up the DNS server configuration
#RUN echo "nameserver 127.0.0.1" | tee /etc/resolv.conf

# Expose ports
EXPOSE 5380/tcp
EXPOSE 53443/tcp
EXPOSE 53/udp
EXPOSE 53/tcp
EXPOSE 853/udp
EXPOSE 853/tcp
EXPOSE 443/udp
EXPOSE 443/tcp
EXPOSE 80/tcp
EXPOSE 8053/tcp
EXPOSE 67/udp

# Define volume
VOLUME ["/etc/dns"]

# Set stop signal and entrypoint
STOPSIGNAL SIGINT
ENTRYPOINT ["dotnet", "/opt/technitium/dns/DnsServerApp.dll"]
CMD ["/etc/dns"]
