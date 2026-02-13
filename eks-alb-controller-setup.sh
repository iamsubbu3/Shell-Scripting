#!/bin/bash
set -e

CLUSTER_NAME="subbu-cluster"
AWS_REGION="us-east-1"

echo "=============================================="
echo " EKS ALB Controller Setup (IRSA Automated)"
echo "=============================================="

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# -------------------------------------------------
# 1️⃣ Enable OIDC
# -------------------------------------------------
echo "Checking OIDC provider..."

OIDC_URL=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query "cluster.identity.oidc.issuer" \
  --output text)

if [ -z "$OIDC_URL" ]; then
  echo "OIDC not found. Installing eksctl..."
  curl -sL https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz | tar xz
  sudo mv eksctl /usr/local/bin

  eksctl utils associate-iam-oidc-provider \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION \
    --approve
else
  echo "OIDC already enabled."
fi

OIDC_PROVIDER=$(echo $OIDC_URL | sed -e "s/^https:\/\///")

# -------------------------------------------------
# 2️⃣ Create IAM Policy (if not exists)
# -------------------------------------------------
echo "Checking IAM policy..."

POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy"

if ! aws iam get-policy --policy-arn $POLICY_ARN >/dev/null 2>&1; then
  echo "Creating IAM Policy..."

  curl -s -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

  aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
else
  echo "IAM Policy already exists."
fi

# -------------------------------------------------
# 3️⃣ Create IAM Role
# -------------------------------------------------
echo "Creating IAM Role..."

cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_PROVIDER:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF

if ! aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole >/dev/null 2>&1; then
  aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --assume-role-policy-document file://trust-policy.json
else
  echo "IAM Role already exists."
fi

aws iam attach-role-policy \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --policy-arn $POLICY_ARN || true

# -------------------------------------------------
# 4️⃣ Create Service Account
# -------------------------------------------------
echo "Creating Kubernetes ServiceAccount..."

kubectl create serviceaccount aws-load-balancer-controller \
  -n kube-system 2>/dev/null || true

kubectl annotate serviceaccount \
  aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::$ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRole \
  --overwrite

# -------------------------------------------------
# 5️⃣ Install AWS Load Balancer Controller
# -------------------------------------------------
echo "Installing AWS Load Balancer Controller..."

helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo update >/dev/null

VPC_ID=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "=============================================="
echo " ALB Controller Installed Successfully ✅"
echo "=============================================="
echo "Now you can create Gateway resources."
echo "ALB will be created automatically."
echo "=============================================="



# -------------------------------------------------
# Commands After Running Shell Scripting
# -------------------------------------------------

# 1. kubectl get deployment -n kube-system aws-load-balancer-controller
# 2. kubectl get pods -n kube-system

