CXX      = clang++-3.2
CXXFLAGS += -std=c++11 -Wall -Werror

#
# Adjust CPPFLAGS and LDFLAGS for libclang
#

#  # When using libclang built by (mac)port
#  CPPFLAGS += -I /opt/local/libexec/llvm-3.2/include/
#  LDFLAGS  += -L /opt/local/libexec/llvm-3.2/lib

   # When using libclang built by (home)brew
   CPPFLAGS += -I/usr/local/opt/llvm32/lib/llvm-3.2/include
   LDFLAGS  += -L/usr/local/opt/llvm32/lib/llvm-3.2/lib

#

SOURCE_FILES = $(wildcard *.cc)
OBJECT_FILES = $(patsubst %.cc,%.o,$(SOURCE_FILES))
TARGETS      = $(patsubst %.cc,%,$(SOURCE_FILES))

LDFLAGS  += -lclang

all : $(TARGETS)

clean:
	$(RM) $(TARGETS)
