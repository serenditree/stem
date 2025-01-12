########################################################################################################################
# Finishing touches
########################################################################################################################
resource "terraform_data" "finally" {
  depends_on = [helm_release.serenditree]

  provisioner "local-exec" {
    command = "./src/finally.sh"
    environment = {
      EXOSCALE_ACCOUNT = var.account
    }
  }
}
