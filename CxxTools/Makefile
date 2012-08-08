CXX      = clang++
CXXFLAGS += -std=c++11 -stdlib=libc++ -Wall -Werror
CXXFLAGS += -I /opt/local/libexec/llvm-3.2/include/
LDFLAGS  += -L /opt/local/libexec/llvm-3.2/lib -lclang

SOURCE_FILES = $(wildcard *.cc)
OBJECT_FILES = $(patsubst %.cc,%.o,$(SOURCE_FILES))
TARGETS      = $(patsubst %.cc,%,$(SOURCE_FILES))

all : $(TARGETS)

clean:
	$(RM) $(TARGETS)
