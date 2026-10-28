FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget unzip libfontconfig1 libx11-6 libxcursor1 libxinerama1 \
    libxext6 libxrender1 libxi6 libxrandr2 libasound2 libpulse0 libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/godot
RUN wget -q https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip -O godot.zip \
    && unzip -q godot.zip \
    && chmod +x Godot_v4.7.2-stable_linux.x86_64 \
    && rm godot.zip

ENV GODOT_BIN=/opt/godot/Godot_v4.7.2-stable_linux.x86_64
ENV FRONTLINE_PORT=7777
WORKDIR /app
COPY . /app

# Generate Godot's import cache for models, textures, and other imported resources.
RUN "$GODOT_BIN" --headless --editor --path /app --import \
    && "$GODOT_BIN" --headless --editor --path /app --quit

EXPOSE 7777/udp
CMD ["/bin/sh", "-c", "exec \"$GODOT_BIN\" --headless --path /app -- --frontline-server"]
