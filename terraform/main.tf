provider "google" {
  version = "~> 2.15"
  project = var.project
  region  = var.region
}

resource "google_compute_instance" "docker-node-" {
  count        = var.node_count
  name         = "docker-node-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["reddit-dock", "http-server", "https-server"]
  boot_disk {
    initialize_params {
      image = var.disk_image
      size = 100
      }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    # путь до публичного ключа
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }

  connection {
    type  = "ssh"
    host  = self.network_interface[0].access_config[0].nat_ip
    user  = "appuser"
    agent = false
    # путь до приватного ключа
    private_key = file(var.private_key_path)
  }

  provisioner "file" {
     source      = "./files/docker-compose.yml"
     destination = "/tmp/docker-compose.yml"
  }

  provisioner "remote-exec" {
    script = "./files/inst_docker copy.sh"
  }
}

resource "google_compute_firewall" "http_https" {
  name    = "allow-http-https"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["reddit-dock"]
}
