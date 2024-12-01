#!/bin/bash

# Stop all Docker containers
echo "Stopping all Docker containers..."
docker stop $(docker ps -aq) || echo "No containers running."

# Remove all Docker containers
echo "Removing all Docker containers..."
docker rm $(docker ps -aq) || echo "No containers to remove."

# Remove all Docker images
echo "Removing all Docker images..."
docker rmi $(docker images -q) --force || echo "No images to remove."

# Remove all Docker volumes
echo "Removing all Docker volumes..."
docker volume rm $(docker volume ls -q) || echo "No volumes to remove."

# Remove all Docker networks (excluding the default ones)
echo "Removing all Docker networks..."
docker network rm $(docker network ls -q) || echo "No networks to remove."

# Remove Docker configuration and cache files
echo "Removing Docker configuration and cache files..."
sudo rm -rf /var/lib/docker
sudo rm -rf ~/.docker

# Optional: Uninstall Docker (uncomment if required)
# echo "Uninstalling Docker..."
# sudo apt-get purge docker-ce docker-ce-cli containerd.io -y
# sudo apt-get autoremove -y

echo "Docker has been completely purged from the system."

