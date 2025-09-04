FROM linuxserver/openssh-server

# Install required packages
RUN apk update && apk add --no-cache \
    nodejs \
    npm \
    nano \
    iputils \
    curl \
    git \
    make \
    g++ \
    python3 \
    zsh \
    bash \
    util-linux \
    pciutils \
    linux-headers

# Create /custom-cont-init.d for user startup scripts
RUN mkdir -p /custom-cont-init.d

# Copy startup script into /custom-cont-init.d
COPY startup.sh /custom-cont-init.d/startup.sh

# Ensure script is executable and owned by root
RUN chmod +x /custom-cont-init.d/startup.sh \
    && chown root:root /custom-cont-init.d/startup.sh
