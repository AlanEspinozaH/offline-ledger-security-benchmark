package main

import (
	"encoding/hex"
	"fmt"
	"os"

	candidatecodec "github.com/AlanEspinozaH/offline-ledger-security-benchmark/implementations/go-fxamacker"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "usage: %s FIXTURE.json\n", os.Args[0])
		os.Exit(2)
	}
	fixture, err := candidatecodec.LoadFixture(os.Args[1])
	if err != nil {
		fmt.Fprintf(os.Stderr, "candidate fixture error: %v\n", err)
		os.Exit(1)
	}
	encoded, err := candidatecodec.Encode(fixture.Record)
	if err != nil {
		fmt.Fprintf(os.Stderr, "candidate encoding error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(hex.EncodeToString(encoded))
}
