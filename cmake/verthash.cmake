if (WITH_VERTHASH)
    add_definitions(/DXMRIG_ALGO_VERTHASH)

    list(APPEND HEADERS_CRYPTO
        src/crypto/verthash/Verthash.h
        src/crypto/verthash/VerthashWrapper.h
        src/crypto/verthash/VerthashConfig.h
        src/crypto/verthash/Vh.h
    )

    list(APPEND SOURCES_CRYPTO
        src/crypto/verthash/Verthash.cpp
        src/crypto/verthash/VerthashWrapper.cpp
        src/crypto/verthash/VerthashConfig.cpp
        src/crypto/verthash/Vh.cpp
    )

    # Add tiny_sha3 library
    list(APPEND HEADERS_CRYPTO
        src/3rdparty/tiny_sha3/sha3.h
    )

    list(APPEND SOURCES_CRYPTO
        src/3rdparty/tiny_sha3/sha3.c
    )

    # Add fopen_utf8 header
    list(APPEND HEADERS_CRYPTO
        src/3rdparty/fopen_utf8.h
    )
else()
    remove_definitions(/DXMRIG_ALGO_VERTHASH)
endif()
