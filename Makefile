.PHONY: check init plan up demo status down clean

check:   ## Check tools and .env (prints names only, never values)
	@scripts/check-prereqs.sh

init:    ## terraform init
	@scripts/tf.sh init -upgrade

plan:    ## Show what would be created
	@scripts/tf.sh plan

up:      ## Create everything (Confluent, Lambda MCP server, SES, Flink agent)
	@scripts/tf.sh apply

demo:    ## Run the scripted Black Friday run end to end
	@scripts/demo.sh

status:  ## Show recent verdicts
	@scripts/show-verdicts.sh

down:    ## Destroy everything
	@scripts/tf.sh destroy

clean:   ## Remove local generated files (not cloud resources)
	rm -rf .generated lambda/build clients/python/.venv
