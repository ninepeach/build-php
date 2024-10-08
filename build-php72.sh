#!/usr/bin/env bash
# Run as root or with sudo
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo."
  exit 1
fi

# Make script exit if a simple command fails and
# Make script print commands being executed
set -e -x

# Ensure required packages are installed
if ! command -v curl &> /dev/null; then
    apt-get update && apt-get install -y curl autoconf libtool build-essential
fi

PHP_VERSION="7.2.34"
ZLIB_VERSION="1.3.1"
LIBXML_VERSION="2.13.4"
OPENSSL_VERSION="1.1.1w"
CURL_VERSION="8.7.1"
FREETYPE_VERSION="2.7.1"
LIBPNG_VERSION="1.6.43"
LIBJPEG_VERSION="9f"
EXT_MONGO_VERSION="1.16.2"
EXT_REDIS_VERSION="5.3.7"

DIR="$(pwd)"
BUILD_DIR="$DIR/build"
BUILD_DEPS_DIR="$BUILD_DIR/deps"
INSTALL_DIR="/usr/local/php"

# Get number of CPU cores, or limit threads to a reasonable default if needed
CPU_CORE=$(grep -c ^processor /proc/cpuinfo)
THREADS=$((CPU_CORE > 4 ? 4 : CPU_CORE))

# Ensure directories exist
mkdir -p "$BUILD_DIR" "$BUILD_DEPS_DIR"

function build_libjpeg {
    cd $BUILD_DIR
    local libjpeg_dir="$BUILD_DIR/jpeg-$LIBJPEG_VERSION"
    if [ ! -d "$libjpeg_dir" ]; then
        echo "Extracting jpegsrc.v$LIBJPEG_VERSION.tar.gz"
        tar -zxf "../src/jpegsrc.v$LIBJPEG_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$libjpeg_dir"
    ./configure --prefix="$BUILD_DEPS_DIR" --enable-shared=no --enable-static=yes
    make -j "$THREADS" && make install
    echo "build libjpeg done"
}

function build_libpng {
    cd $BUILD_DIR
    local libpng_dir="$BUILD_DIR/libpng-$LIBPNG_VERSION"
    if [ ! -d "$libpng_dir" ]; then
        echo "Extracting libpng-$LIBPNG_VERSION.tar.gz"
        tar -zxf "../src/libpng-$LIBPNG_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$libpng_dir"
    ./configure --prefix="$BUILD_DEPS_DIR" --enable-shared=no --enable-static=yes
    make -j "$THREADS" && make install
    echo "build libpng done"
}

function build_freetype {
    cd $BUILD_DIR
    local freetype_dir="$BUILD_DIR/freetype-$FREETYPE_VERSION"
    if [ ! -d "$freetype_dir" ]; then
        echo "Extracting freetype-$FREETYPE_VERSION.tar.gz"
        tar -zxf "../src/freetype-$FREETYPE_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$freetype_dir"
    ./configure --prefix="$BUILD_DEPS_DIR" --enable-shared=no --enable-static=yes
    make -j "$THREADS" && make install
    echo "build freetype done"
}

function build_zlib {
    cd $BUILD_DIR
    local zlib_dir="$BUILD_DIR/zlib-$ZLIB_VERSION"
    if [ ! -d "$zlib_dir" ]; then
        echo "Extracting zlib-$ZLIB_VERSION.tar.gz"
        tar -zxf "../src/zlib-$ZLIB_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$zlib_dir"
    ./configure --prefix="$BUILD_DEPS_DIR" --static
    make -j "$THREADS" && make install
    echo "build zlib done"
}

function build_libxml2 {
    cd $BUILD_DIR
    local libxml2_dir="$BUILD_DIR/libxml2-$LIBXML_VERSION"
    if [ ! -d "$libxml2_dir" ]; then
        echo "Extracting libxml2-$LIBXML_VERSION.tar.gz"
        tar -zxf "../src/libxml2-$LIBXML_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$libxml2_dir"
    ./autogen.sh --prefix="$BUILD_DEPS_DIR" --without-iconv --without-python --without-lzma --with-zlib="$BUILD_DEPS_DIR" --enable-shared=no --enable-static=yes
    make -j "$THREADS" && make install
    echo "build libxml2 done"
}

function build_curl {
    cd $BUILD_DIR
    local curl_dir="$BUILD_DIR/curl-$CURL_VERSION"
    if [ ! -d "$curl_dir" ]; then
        echo "Extracting curl-$CURL_VERSION.tar.gz"
        tar -zxf "../src/curl-$CURL_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$curl_dir"
    ./configure --prefix="$BUILD_DEPS_DIR" --disable-shared --enable-static --with-zlib="$BUILD_DEPS_DIR" --with-ssl="$BUILD_DEPS_DIR"
    make -j "$THREADS" && make install
    echo "build curl done"
}

function build_openssl {
    cd $BUILD_DIR
    local openssl_dir="$BUILD_DIR/openssl-$OPENSSL_VERSION"
    if [ ! -d "$openssl_dir" ]; then
        echo "Extracting openssl-$OPENSSL_VERSION.tar.gz"
        tar -zxf "../src/openssl-$OPENSSL_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$openssl_dir"
    ./config --prefix="$BUILD_DEPS_DIR" --openssldir="$BUILD_DEPS_DIR" --libdir="$BUILD_DEPS_DIR/lib" no-shared -static
    make -j "$THREADS" && make install
    echo "build openssl done"
}

function build_php {
    cd $BUILD_DIR
    local php_dir="$BUILD_DIR/php-$PHP_VERSION"
    if [ ! -d "$php_dir" ]; then
        echo "Extracting php-$PHP_VERSION.tar.gz"
        tar -zxf "../src/php-$PHP_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$php_dir"
    
    ./configure --prefix="$INSTALL_DIR" \
        --with-config-file-path="$INSTALL_DIR/etc" \
        --enable-bcmath --enable-cli --enable-mbstring \
        --enable-mysqlnd --enable-opcache --enable-zip \
        --with-fpm-user=www --with-fpm-group=www \
        --with-zlib="$BUILD_DEPS_DIR" --with-libxml-dir="$BUILD_DEPS_DIR" \
        --with-openssl="$BUILD_DEPS_DIR" --with-curl="$BUILD_DEPS_DIR" \
        --with-jpeg-dir="$BUILD_DEPS_DIR" --with-png-dir="$BUILD_DEPS_DIR" \
        --with-gd --with-freetype-dir="$BUILD_DEPS_DIR" --with-pdo-mysql=mysqlnd \
        --disable-cgi --disable-phpdbg --without-pear --without-iconv
    make -j "$THREADS" && make install

    # Handle php.ini
    cp php.ini-production "$INSTALL_DIR/etc/php.ini"
    sed -i 's/memory_limit = .*/memory_limit = 512M/' "$INSTALL_DIR/etc/php.ini"
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' "$INSTALL_DIR/etc/php.ini"
    sed -i 's/post_max_size = .*/post_max_size = 100M/' "$INSTALL_DIR/etc/php.ini"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$INSTALL_DIR/etc/php.ini"

    # Handle php-fpm.conf
    mv $INSTALL_DIR/etc/php-fpm.conf.default $INSTALL_DIR/etc/php-fpm.conf
    mv $INSTALL_DIR/etc/php-fpm.d/www.conf.default $INSTALL_DIR/etc/php-fpm.d/www.conf
    
    # Adjust php-fpm settings
    sed -i 's/listen = .*/listen = \/var\/run\/php-fpm.sock/' "$INSTALL_DIR/etc/php-fpm.d/www.conf"
    sed -i 's/user = .*/user = www/' "$INSTALL_DIR/etc/php-fpm.d/www.conf"
    sed -i 's/group = .*/group = www/' "$INSTALL_DIR/etc/php-fpm.d/www.conf"
    sed -i 's/pm.max_children = .*/pm.max_children = 50/' "$INSTALL_DIR/etc/php-fpm.d/www.conf"
    
    echo "build php and configure php.ini/php-fpm done"
}

function build_php_exts {
    cd $BUILD_DIR
    # Build Mongo extension
    local mongo_dir="$BUILD_DIR/mongo-php-driver-$EXT_MONGO_VERSION"
    if [ ! -d "$mongo_dir" ]; then
        echo "Extracting mongo-php-driver-$EXT_MONGO_VERSION.tar.gz"
        tar -zxf "../src/mongo-php-driver-$EXT_MONGO_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$mongo_dir"
    $INSTALL_DIR/bin/phpize
    ./configure --with-php-config="$INSTALL_DIR/bin/php-config" --with-mongodb-zlib="$BUILD_DEPS_DIR" --with-openssl-dir="$BUILD_DEPS_DIR"
    make -j "$THREADS" && make install
    echo "build php ext mongo done"

    cd $BUILD_DIR
    # Build Redis extension
    local redis_dir="$BUILD_DIR/phpredis-$EXT_REDIS_VERSION"
    if [ ! -d "$redis_dir" ]; then
        echo "Extracting phpredis-$EXT_REDIS_VERSION.tar.gz"
        tar -zxf "../src/phpredis-$EXT_REDIS_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    cd "$redis_dir"
    $INSTALL_DIR/bin/phpize
    ./configure --with-php-config="$INSTALL_DIR/bin/php-config"
    make -j "$THREADS" && make install
    echo "build php ext redis done"
}

# Main execution starts here

# Build dependencies
build_libjpeg
build_libpng
build_freetype
build_zlib
build_libxml2
build_openssl
build_curl

# Build PHP and extensions
build_php
build_php_exts

echo "PHP and dependencies build complete!"