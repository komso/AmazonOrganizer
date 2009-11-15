.PHONY : all
all : runtest
	./runtest
objc_path = ../AmazonOrganizer
CFLAGS += -I $(objc_path)

runtest : runtest.o Keychain.o
	gcc -o $@ $^ -framework Cocoa -framework RubyCocoa -framework Security

runtest.o : runtest.m
Keychain.o : $(objc_path)/Keychain.h $(objc_path)/Keychain.m
	gcc -c $(objc_path)/Keychain.m

