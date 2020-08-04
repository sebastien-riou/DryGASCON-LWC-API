Notation:
Na, Nm, Nc, Nh : the number of complete blocks of associated data,plaintext, ciphertext, and hash message, respectively
Ina, Inm, Inc, Inh : binary variables equal to 1 if the last block of the respective data type is incomplete, and 0 otherwise
Bla, Blm, Blc, Blh : the number of bytes in the incomplete block of associated data, plaintext, ciphertext, and hash message, respectively.

    IL   = Initial Load (Key + Firsrt block of data)
    KS   = KeySet
    NPUB = Npub processing time
    BLK  = Block processing time
    G    = Gascon Rounds
    OUT  = Output time

---

v1: drygascon128k32

a. Design goal
* Support for authenticated encryption, decryption, and hashing.
* Iterative architecture.
* No BRAMs, no DSP units.

b. Supported maximum sizes of inputs
* MAX


c. Reference software implementation
* crypto_aead/drygascon128k32/ref    (New reference implementation not yet published)
* crypto_hash/drygascon128/ref


d. Non-default values of generics and constants
* None

e. Block sizes

* AD block size = 128 bits
* Plaintext/Ciphertext block size = 128 bits
* Hash block size = 128 bits

f. Execution times

* Execution time of authenticated encryption:

    * IL   = 8
    * KS   = 1
    * INIT = 25
    * BLK  = 20
    * OUT  = 5

    IL + KS + INIT + (BLK * Na) + (BLK * Nm) + OUT


* Execution time of authenticated decryption:

    * IL   = 8
    * KS   = 1
    * INIT = 25
    * BLK  = 20
    * OUT  = 1

    IL + KS + INIT + (BLK * Na) + (BLK * Nc) + OUT

* Execution time of hashing:

    * IL   = 4
    * KS   = 1
    * INIT = 25
    * BLK  = 20
    * G    = 7
    * OUT  = 5

    IL + KS + (BLK * Nh) + G + OUT



g. Latencies
Latency of authenticated encryption:
20

Latency of authenticated decryption:
20

h. Difference between execution times for a new key and the same key

4