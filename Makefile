DC = docker compose

unit-tests: dc-build unit-tests-ldc unit-tests-dmd
.PHONY: unit-tests

unit-tests-ldc:
	$(DC) run --rm ldc dub -q test --compiler=ldc2 --config=vibed
	$(DC) run --rm ldc dub build -b release --compiler=ldc2 --config=vibed
	$(DC) run --rm ldc dub -q test --compiler=ldc2 --config=std
	$(DC) run --rm ldc dub build -b release --compiler=ldc2 --config=std
.PHONY: unit-tests-ldc

unit-tests-dmd:
	$(DC) run --rm dmd dub -q test --compiler=dmd --config=vibed
	$(DC) run --rm dmd dub build -b release --compiler=dmd --config=vibed
	$(DC) run --rm dmd dub -q test --compiler=dmd --config=std
	$(DC) run --rm dmd dub build -b release --compiler=dmd --config=std
.PHONY: unit-tests-dmd

shell-ldc:
	$(DC) run --rm ldc bash
.PHONY: shell-ldc

shell-dmd:
	$(DC) run --rm dmd bash
.PHONY: shell-dmd

dc-build:
	$(DC) build
.PHONY: dc-build

