from python:3

RUN apt-get update && apt-get -y install --no-install-recommends \
    libfreetype6-dev \
    libportmidi-dev \
    libsdl2-dev \
    libsdl2-image-dev \
    libsdl2-mixer-dev \
    libsdl2-ttf-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install pygame
RUN sudo apt-get install libjpeg-dev libsdl2-image-2.0-0 vlc python3-pip ffmpeg libsdl2-ttf-dev -y

CMD ["python3"]
