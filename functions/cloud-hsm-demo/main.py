# Import base64 for printing the ciphertext.
import base64

# Import cryptographic helpers from the cryptography package.
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding

# Import the client library.
from google.cloud import kms

def cloud_hsm_demo(request):

    request_json = request.get_json()
    if request.args and 'message' in request.args:
        user_input = request.args.get('message')
    elif request_json and 'message' in request_json:
        user_input = request_json['message']
    else:
        return f'Unable to read input!'
    
    project_id  = 'pensande'
    location_id = 'asia-south2'
    key_ring_id = 'delhi-hsm-test'
    key_id      = 'hsm-asymmetric-decrypt'
    version_id  = '1'
    
    ciphertext  = base64.b64decode(user_input)
    outputtext  = decrypt_asymmetric(project_id, location_id, key_ring_id, key_id, version_id, ciphertext)
    bank_cipher_text = encrypt_external(outputtext.plaintext)

    return base64.b64encode(bank_cipher_text)

def encrypt_asymmetric(
    project_id: str,
    location_id: str,
    key_ring_id: str,
    key_id: str,
    version_id: str,
    plaintext: str,
) -> bytes:
    """
    Encrypt plaintext using the public key portion of an asymmetric key.

    Args:
        project_id (string): Google Cloud project ID (e.g. 'my-project').
        location_id (string): Cloud KMS location (e.g. 'us-east1').
        key_ring_id (string): ID of the Cloud KMS key ring (e.g. 'my-key-ring').
        key_id (string): ID of the key to use (e.g. 'my-key').
        version_id (string): ID of the key version to use (e.g. '1').
        plaintext (string): message to encrypt

    Returns:
        bytes: Encrypted ciphertext.

    """

    # Convert the plaintext to bytes.
    plaintext_bytes = plaintext.encode("utf-8")

    # Create the client.
    client = kms.KeyManagementServiceClient()

    # Build the key version name.
    key_version_name = client.crypto_key_version_path(
        project_id, location_id, key_ring_id, key_id, version_id
    )

    # Get the public key.
    public_key = client.get_public_key(request={"name": key_version_name})

    # Extract and parse the public key as a PEM-encoded RSA key.
    pem = public_key.pem.encode("utf-8")
    rsa_key = serialization.load_pem_public_key(pem, default_backend())

    # Construct the padding. Note that the padding differs based on key choice.
    sha256 = hashes.SHA256()
    mgf = padding.MGF1(algorithm=sha256)
    pad = padding.OAEP(mgf=mgf, algorithm=sha256, label=None)

    # Encrypt the data using the public key.
    ciphertext = rsa_key.encrypt(plaintext_bytes, pad)
    print(f"Ciphertext: {base64.b64encode(ciphertext)!r}")
    return ciphertext

def decrypt_asymmetric(
    project_id: str,
    location_id: str,
    key_ring_id: str,
    key_id: str,
    version_id: str,
    ciphertext: bytes,
) -> kms.DecryptResponse:
    """
    Decrypt the ciphertext using an asymmetric key.

    Args:
        project_id (string): Google Cloud project ID (e.g. 'my-project').
        location_id (string): Cloud KMS location (e.g. 'us-east1').
        key_ring_id (string): ID of the Cloud KMS key ring (e.g. 'my-key-ring').
        key_id (string): ID of the key to use (e.g. 'my-key').
        version_id (string): ID of the key version to use (e.g. '1').
        ciphertext (bytes): Encrypted bytes to decrypt.

    Returns:
        DecryptResponse: Response including plaintext.

    """

    # Create the client.
    client = kms.KeyManagementServiceClient()

    # Build the key version name.
    key_version_name = client.crypto_key_version_path(
        project_id, location_id, key_ring_id, key_id, version_id
    )

    # Optional, but recommended: compute ciphertext's CRC32C.
    # See crc32c() function defined below.
    ciphertext_crc32c = crc32c(ciphertext)

    # Call the API.
    decrypt_response = client.asymmetric_decrypt(
        request={
            "name": key_version_name,
            "ciphertext": ciphertext,
            "ciphertext_crc32c": ciphertext_crc32c,
        }
    )

    # Optional, but recommended: perform integrity verification on decrypt_response.
    # For more details on ensuring E2E in-transit integrity to and from Cloud KMS visit:
    # https://cloud.google.com/kms/docs/data-integrity-guidelines
    if not decrypt_response.verified_ciphertext_crc32c:
        raise Exception("The request sent to the server was corrupted in-transit.")
    if not decrypt_response.plaintext_crc32c == crc32c(decrypt_response.plaintext):
        raise Exception(
            "The response received from the server was corrupted in-transit."
        )
    # End integrity verification

    print(f"Plaintext: {decrypt_response.plaintext!r}")
    return decrypt_response


def crc32c(data: bytes) -> int:
    """
    Calculates the CRC32C checksum of the provided data.
    Args:
        data: the bytes over which the checksum should be calculated.
    Returns:
        An int representing the CRC32C checksum of the provided bytes.
    """
    import crcmod  # type: ignore

    crc32c_fun = crcmod.predefined.mkPredefinedCrcFun("crc-32c")
    return crc32c_fun(data)

def encrypt_external(plaintext):
    import os
    
    # Extract and parse the public key as a PEM-encoded RSA key.
    bankpublickey = os.environ.get('BANKPUBLICKEY', 'Specified environment variable is not set.')
    pem = bankpublickey.encode("utf-8")
    rsa_key = serialization.load_pem_public_key(pem, default_backend())

    # Construct the padding. Note that the padding differs based on key choice.
    sha256 = hashes.SHA256()
    mgf = padding.MGF1(algorithm=sha256)
    pad = padding.OAEP(mgf=mgf, algorithm=sha256, label=None)

    # Encrypt the data using the public key.
    ciphertext = rsa_key.encrypt(plaintext, pad)
    print(f"Ciphertext: {base64.b64encode(ciphertext)!r}")
    return ciphertext
