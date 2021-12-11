echo '
# HELP gauge_test тестовая gauge
# TYPE gauge_test gauge
gauge_test{label="scrape_gauge"} 3.145

# HELP histogram_test тестовая гистограмма
# TYPE histogram_test histogram
histogram_test_bucket{le="0.01"} 63.0
histogram_test_bucket{le="0.025"} 70.0
histogram_test_bucket{le="0.05"} 90.0
histogram_test_bucket{le="0.075"} 100.0
histogram_test_bucket{le="+Inf"} 100.0
histogram_test_count 100.0
histogram_test_sum 7.256

# TYPE summary_test summary
summary_test{label="scrape_summary"} 35

# TYPE counter_test counter
counter_test{label="scrape_counter"} 100

' | curl --data-binary @- http://localhost:9091/metrics/job/1c/instance/1c_bit
