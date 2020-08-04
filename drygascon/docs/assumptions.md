A. Hardware description language used


B. Use of the hardware description language source files provided as a part of the
Development Package

| File name           | Used (Y/N) | Release number | Functional Modifications (Y/N) |
| ------------------- | ---------- | -------------- | ------------------------------ |
| NIST_LWAPI_pkg.vhd  | Y          | 1.0.3          | N                              |
| StepDownCountLd.vhd | Y          | 1.0.3          | N                              |
| data_piso.vhd       | Y          | 1.0.3          | N                              |
| data_sipo.vhd       | Y          | 1.0.3          | N                              |
| key_piso.vhd        | Y          | 1.0.3          | N                              |
| PreProcessor.vhd    | Y          | 1.0.3          | N                              |
| PostProcessor.vhd   | Y          | 1.0.3          | N                              |
| fwft_fifo.vhd       | Y          | 1.0.3          | N                              |
| LWC.vhd             | Y          | 1.0.3          | N                              |


C. Supported types and order of segment types

a. input to encryption          npub, ad, data
b. output from encryption       data, tag
c. input to decryption          npub, ad, data, tag
d. output from decryption       data
e. input to hash                message
f. output from hash             hash_tag

D. Deviations from the LWC Hardware API v1.0 specification

