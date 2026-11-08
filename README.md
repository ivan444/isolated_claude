# A Docker based solution for running isolated Claude Code

Isolation in this context means that Claude Code:
- has read & write access to the current working directory and its
  subdirectories,
- can access external network (Internet), but can't access the local network
  (other devices and services on your home network),
- writes files as the user who started it (i.e. the same user ID & group ID).


## 0) Prereqisite

Install Docker: <https://docs.docker.com/engine/install/>


## 1) Setup isolated network for Docker containers

Prevent Docker container from reaching out the services on local IPv4 network,
while allowing it to connect to the services on the Internet.

0) Install the prerequisites:
```bash
sudo apt install iptables-persistent
```

1) Create a dedicated network with a fixed bridge name:
```bash
docker network create \
  --subnet 172.30.0.0/24 \
  --opt com.docker.network.bridge.name=br-isolated \
  isolated
```

2) Add rules for that bridge only:
```bash
# Block this bridge from reaching private ranges (LAN, other Docker networks, link-local)
sudo iptables -I DOCKER-USER -i br-isolated -d 169.254.0.0/16 -j DROP
sudo iptables -I DOCKER-USER -i br-isolated -d 192.168.0.0/16 -j DROP
sudo iptables -I DOCKER-USER -i br-isolated -d 172.16.0.0/12  -j DROP
sudo iptables -I DOCKER-USER -i br-isolated -d 10.0.0.0/8     -j DROP

# Optional: allow DNS to your LAN resolver
sudo iptables -I DOCKER-USER -i br-isolated -d 192.168.1.1 -p udp --dport 53 -j RETURN
sudo iptables -I DOCKER-USER -i br-isolated -d 192.168.1.1 -p tcp --dport 53 -j RETURN

# Allow replies on connections that were opened from outside (needed if you use -p)
sudo iptables -I DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN

# Block the container from initiating connections to the host itself
sudo iptables -I INPUT -i br-isolated -m conntrack --ctstate NEW -j DROP
```

NOTE: `192.168.1.1` here is the local DNS resolved -- adjust if it's different.

3) Persist the new iptables across reboots:
```bash
sudo netfilter-persistent save
```


## 2) Build the image and storage volume

Build the image:
```bash
docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) --build-arg USERNAME=${USER} -t claude-sandbox-${USER} -f Dockerfile .
```

Create named volume for the settings:
```bash
docker volume create claude-home-${USER}
```


## 3) Add `claude` function to your `.zshrc`/`.bashrc` for simpler usage

```bash
function claude {
  docker run --rm -it \
    --network isolated \
    --ip 172.30.0.$(($RANDOM % 254 + 1)) \
    --user $(id -u):$(id -g) \
    -v "$PWD:/workspace" \
    -v claude-home-${USER}:"/home/$USER/" \
    claude-sandbox-${USER}
}
```

The `RANDOM` here enables running multiple isolated Claude Code instances (each
gets its own IP, with low probability of collision).


## 4) Use it

From the directory you want Claude Code to access, run:
```bash
claude
```

The named claude home volume keeps container-local settings, credentials, and
sessions between runs.

