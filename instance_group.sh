#!/bin/bash

# Set variables
PROJECT="your_project_id"
ZONE="asia-east2-c"
DISK_NAME="your_vm_name"
SNAPSHOT_NAME="your_snapshot_name-snapshot-$(date +%Y%m%d)"
STORAGE_LOCATION="asia-east2"
IMAGE_NAME="your_image_name-image-$(date +%Y%m%d)"
TEMPLATE_NAME="your_template_name-template-$(date +%Y%m%d)"
INSTANCE_GROUP_NAME="your_group_instance_name-instance-group-$(date +%Y%m%d)"
HEALTH_CHECK_NAME="your_healthcheck_name-health-check-$(date +%Y%m%d)"

# Enable required APIs
echo "Enabling required Google Cloud APIs..."
gcloud services enable compute.googleapis.com --project=$PROJECT

# Authenticate and set project
echo "Setting project to $PROJECT..."
gcloud config set project $PROJECT

# Create the snapshot without the --guest-flush flag
echo "Creating snapshot $SNAPSHOT_NAME from disk $DISK_NAME..."
gcloud compute snapshots create $SNAPSHOT_NAME \
  --source-disk=$DISK_NAME \
  --source-disk-zone=$ZONE \
  --storage-location=$STORAGE_LOCATION

# Wait for the snapshot to be available
echo "Waiting for the snapshot to be available..."
sleep 30  # Adjust this sleep time if needed to ensure the snapshot is created

# Create an image from an existing snapshot
echo "Creating image $IMAGE_NAME from snapshot $SNAPSHOT_NAME..."
gcloud compute images create $IMAGE_NAME \
  --project=$PROJECT \
  --source-snapshot=$SNAPSHOT_NAME \
  --architecture="X86_64" \
  --licenses="projects/ubuntu-os-cloud/global/licenses/ubuntu-2204-lts" \
  --guest-os-features="VIRTIO_SCSI_MULTIQUEUE,SEV_CAPABLE,SEV_SNP_CAPABLE,SEV_LIVE_MIGRATABLE,SEV_LIVE_MIGRATABLE_V2,IDPF,TDX_CAPABLE,UEFI_COMPATIBLE,GVNIC"

# Output image details
echo "Image $IMAGE_NAME created in project $PROJECT using snapshot $SNAPSHOT_NAME."
sleep 5  # Wait for a few seconds for the image to propagate
gcloud compute images describe $IMAGE_NAME --project=$PROJECT

# Script to create an instance template
echo "Creating instance template $TEMPLATE_NAME..."
STARTUP_SCRIPT="#!/bin/bash
# Change SSH port to 8734
sed -i 's/^#Port 22/Port 8734/' /etc/ssh/sshd_config
# Allow traffic on port 8734 through the firewall
ufw allow 8734/tcp
# Restart SSH service to apply changes
systemctl restart sshd"

gcloud compute instance-templates create $TEMPLATE_NAME \
  --project=$PROJECT \
  --machine-type="e2-standard-2" \
  --network="projects/$PROJECT/global/networks/default" \
  --tags="innovehealth" \
  --image="projects/$PROJECT/global/images/$IMAGE_NAME" \
  --image-project=$PROJECT \
  --boot-disk-type="pd-balanced" \
  --boot-disk-size="10" \
  --metadata=startup-script="$STARTUP_SCRIPT",ssh-keys="username:your_actual_content_of_your_ssh.pub" \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --region="asia-east2"

# Create a health check for the instance group
echo "Creating health check $HEALTH_CHECK_NAME..."
gcloud compute health-checks create http $HEALTH_CHECK_NAME \
  --project=$PROJECT \
  --port=80 \
  --request-path="/"

# Create the instance group with initial size
echo "Creating instance group $INSTANCE_GROUP_NAME..."
gcloud compute instance-groups managed create $INSTANCE_GROUP_NAME \
  --project=$PROJECT \
  --zone=$ZONE \
  --template=$TEMPLATE_NAME \
  --size=1

# Set the autoscaling parameters to manage replicas between min and max
echo "Setting autoscaling for instance group $INSTANCE_GROUP_NAME..."
gcloud compute instance-groups managed set-autoscaling $INSTANCE_GROUP_NAME \
  --project=$PROJECT \
  --zone=$ZONE \
  --min-num-replicas=1 \
  --max-num-replicas=2 \
  --target-cpu-utilization=0.6

# Output result
echo "Instance group $INSTANCE_GROUP_NAME created in project $PROJECT with autoscaling set to 1 to 2 replicas."
