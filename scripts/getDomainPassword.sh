#
#  Copyright 2019 Google Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
gsutil cp gs://-deployment-staging/output/domain-admin-password.bin .
gcloud kms decrypt --key mssqldev-deployment-key --location us-east1 --keyring mssqldev-deployment-ring --ciphertext-file domain-admin-password.bin --plaintext-file domain-admin-password.txt
cat domain-admin-password.txt
rm domain-admin-password.txt
