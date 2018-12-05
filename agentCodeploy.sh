sudo apt-get -y update
sudo apt-get -y install ruby wget
cd /home/ubuntu
sudo wget https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install
chmod +x ./install
./install auto