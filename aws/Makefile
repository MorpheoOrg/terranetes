etcd-test-setup:
	@echo "Setting up test etcd cluster"
	cd ./etcd_cluster/tests && ./run_tests.sh setup && cd -

etcd-test-teardown:
	@echo "Destroying test etcd cluster"
	cd ./etcd_cluster/tests && ./run_tests.sh teardown && cd -

etcd-test-run:
	@echo "Launch compliance tests on etcd cluster"
	cd ./etcd_cluster/tests && ./run_tests.sh setup && cd -
