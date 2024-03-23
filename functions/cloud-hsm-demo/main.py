import os
import base64    
from google.cloud import kms

# Import cryptographic helpers from the cryptography package.
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding

def cloud_hsm_demo(request):
    request_json = request.get_json()
    if request.args and 'message' in request.args:
        user_input = request.args.get('message')
    elif request_json and 'message' in request_json:
        user_input = request_json['message']
    else:
        return f'Unable to read input!'
    
    cloud_hsm_key = os.environ.get('CLOUD_HSM_KEY', 'Specified environment variable is not set.')
    
    ciphertext  = base64.b64decode(user_input)
    outputtext  = decrypt_asymmetric(cloud_hsm_key, ciphertext)
    bank_cipher_text = encrypt_external(outputtext.plaintext)

    return base64.b64encode(bank_cipher_text)

def encrypt_asymmetric(key_version_name: str, plaintext: str) -> bytes:   
    # Convert the plaintext to bytes.
    plaintext_bytes = plaintext.encode("utf-8")

    # Create the client.
    client = kms.KeyManagementServiceClient()

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

def decrypt_asymmetric(key_version_name: str, ciphertext: bytes) -> kms.DecryptResponse:
    # Create the client.
    client = kms.KeyManagementServiceClient()

    # Optional, but recommended: compute ciphertext's CRC32C.
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
    import crcmod  # type: ignore

    crc32c_fun = crcmod.predefined.mkPredefinedCrcFun("crc-32c")
    return crc32c_fun(data)

def encrypt_external(plaintext): 
    # Extract and parse the public key as a PEM-encoded RSA key.
    bankpublickey = os.environ.get('BANK_PUBLIC_KEY', 'Specified environment variable is not set.')
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
