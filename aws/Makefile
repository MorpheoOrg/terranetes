etcd-test-setup:
	@echo "Setting up test etcd cluster"
	cd ./etcd_cluster/tests && ./run_tests.sh setup && cd -

etcd-test-teardown:
	@echo "Destroying test etcd cluster"
	cd ./etcd_cluster/tests && ./run_tests.sh teardown && cd -

etcd-test-run:
	@echo "Launch compliance tests on etcd cluster"
	cd ./etcd_cluster/tests && ./run_tests.sh test && cd -

etcd-test:
	@echo "Setup etcd cluster, run tests on it and clean everything up"
	cd ./etcd_cluster/tests && ./run_tests.sh setup && ./run_tests.sh test && ./run_tests.sh teardown  && cd -

kubernetes-test-setup:
	@echo "Setting up test kubernetes cluster"
	cd ./tests && ./run_tests.sh setup && cd -

kubernetes-test-teardown:
	@echo "Destroying test kubernetes cluster"
	cd ./tests && ./run_tests.sh teardown && cd -

kubernetes-test-run:
	@echo "Launch compliance tests on kubernetes cluster"
	cd ./tests && ./run_tests.sh test && cd -

kubernetes-test:
	@echo "Setup etcd cluster, run tests on it and clean everything up"
	cd ./tests && ./run_tests.sh setup && ./run_tests.sh test && ./run_tests.sh teardown  && cd -
