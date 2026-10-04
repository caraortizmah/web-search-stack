# How to Run

Short setup guide. For architecture details, see the root `README.md`.
For workflow logic, see `workflows/README_n8n.md`.

---

## 1. Check that Docker is not already running

This project expects Docker to be started manually, not as a background
service.

    sudo systemctl status docker

If it says `active (running)`, stop it first:

    sudo systemctl stop docker

---

## 2. Start the stack

From the folder containing `docker-compose.yml`:

    sudo systemctl start docker
    docker compose up -d

Check that all containers are up:

    docker compose ps

You should see `gluetun`, `n8n`, `mymongodb`, and `flaresolverr`.

---

## 3. If something fails

Most first-run problems come from the VPN credentials.

- If Gluetun restarts in a loop or the containers stay unhealthy,
  check the WireGuard private key in your `.env` file. See the root
  `README.md`, section 2, for how the key is obtained and stored.

- If the stack starts but workflows fail, see `workflows/README.md`
  for details on the individual nodes and sources.

Quick check of the VPN:

    docker logs gluetun | tail -20
    docker exec n8n wget -qO- https://ifconfig.me

The IP shown should differ from your real public IP.

---

## 4. Open n8n in the browser

In your browser, open:

    http://127.0.0.1:5678

If port 5678 is mapped differently in your compose file, use that port
instead.

---

## 5. First-time setup inside n8n

On first load you will be asked to create an owner account. Use any
email and password you want; this is local to your instance.

After logging in:

- The AI Assistant prompt is optional. Skip it or enable it later.
- Go to Workflows. If you cloned the repository, import the workflow
  JSON from the `workflows/` folder:
  menu in the top-right corner, then Import from File.

---

## 6. What to expect

- The workflow will not run until you import it and reconnect any
  credentials it references.
- The first run may take a minute. Sources protected by Cloudflare go
  through FlareSolverr, which is slower.
- Results are written to MongoDB. To verify, see `workflows/README_n8n.md`.

---

## 7. Stopping the stack

    docker compose down

This stops and removes the containers. Volumes are preserved, so your
n8n workflows and MongoDB data remain.

To also remove the data volumes (destructive, not recommended):

    docker compose down -v

---

## Related documents

- Root `README.md`: architecture, VPN, container structure,
  repository layout, secrets handling.
- `workflows/README_n8n.md`: workflow schematic, hash logic, credentials
  inside workflows, how to add a new source.
