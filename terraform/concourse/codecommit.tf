resource "aws_codecommit_repository" "concourse-pool" {
  provider        = "aws.codecommit"
  repository_name = "concourse-pool-${var.env}"
  description     = "Git repository to keep concourse pool resource locks"
  default_branch  = "master"
}

resource "aws_iam_user" "git" {
  name = "git-${var.env}"
}

resource "aws_iam_user_group_membership" "git_concourse_pool" {
  user   = "${aws_iam_user.git.name}"
  groups = ["concourse-pool-git-rw"]
}

resource "aws_iam_user_ssh_key" "git" {
  username   = "${aws_iam_user.git.name}"
  encoding   = "PEM"
  public_key = "${var.git_rsa_id_pub}"
}
