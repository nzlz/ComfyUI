# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim

ARG PYTORCH_INSTALL_ARGS=""
ARG EXTRA_ARGS=""
ARG USERNAME=comfyui
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Fail fast on errors or unset variables
SHELL ["/bin/bash", "-eux", "-o", "pipefail", "-c"]

RUN <<EOF
	groupadd --gid ${USER_GID} ${USERNAME}
	useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME}
EOF

RUN <<EOF
	apt-get update
	apt-get install -y --no-install-recommends \
		git \
		git-lfs \
		rsync \
		fonts-recommended
EOF

# Create required directories with proper permissions
RUN mkdir -p /app/input/3d \
    /app/models \
    /app/output/temp \
    /app/output \
    /app/user \
    /app/custom_nodes \
    /app/custom_venv && \
    chown -R ${USER_UID}:${USER_GID} /app

# run instructions as user
USER ${USER_UID}:${USER_GID}

WORKDIR /app

ENV XDG_CACHE_HOME=/cache
ENV PIP_CACHE_DIR=/cache/pip
ENV VIRTUAL_ENV=/app/venv

# create cache directory. During build we will use a cache mount,
# but later this is useful for custom node installs
RUN --mount=type=cache,target=/cache/,uid=${USER_UID},gid=${USER_GID} \
	mkdir -p ${PIP_CACHE_DIR}

# create virtual environment to manage packages
RUN python -m venv ${VIRTUAL_ENV}

# run python from venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

RUN --mount=type=cache,target=/cache/,uid=${USER_UID},gid=${USER_GID} \
	pip install torch torchvision torchaudio ${PYTORCH_INSTALL_ARGS}

# copy requirements files first so packages can be cached separately
COPY --chown=${USER_UID}:${USER_GID} requirements.txt .
RUN --mount=type=cache,target=/cache/,uid=${USER_UID},gid=${USER_GID} \
	pip install -r requirements.txt

# Not strictly required for comfyui, but prevents non-working variants of
# cv2 being pulled in by custom nodes
RUN --mount=type=cache,target=/cache/,uid=${USER_UID},gid=${USER_GID} \
	pip install opencv-python-headless

# Copy entrypoint script first for better caching
COPY --chown=${USER_UID}:${USER_GID} entrypoint.sh /app/entrypoint.sh

# Copy application files
COPY --chown=${USER_UID}:${USER_GID} . .

COPY --chown=nobody:${USER_GID} .git .git

# default environment variables
ENV COMFYUI_ADDRESS=0.0.0.0
ENV COMFYUI_PORT=8188
ENV COMFYUI_EXTRA_BUILD_ARGS="${EXTRA_ARGS}"
ENV COMFYUI_EXTRA_ARGS=""

# default start command
ENTRYPOINT ["/app/entrypoint.sh"]
CMD python -u main.py --listen "${COMFYUI_ADDRESS}" --port "${COMFYUI_PORT}" ${COMFYUI_EXTRA_BUILD_ARGS} ${COMFYUI_EXTRA_ARGS}
