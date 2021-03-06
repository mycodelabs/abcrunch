require 'spec_helper'

describe "AbCrunch::StrategyBestConcurrency" do

  describe "#run" do
    before :each do
      @test_page = AbCrunchSpec.new_page
      @fake_result = AbCrunchSpec.new_result

      stub(AbCrunch::BestRun).of_avg_response_time { @fake_result }
      stub(AbCrunch::StrategyBestConcurrency).find_best_concurrency { @fake_result }
      stub(AbCrunch::Logger).log
    end

    it "should get the baseline using the global options merged with the page" do
      page = AbCrunch::Config.best_concurrency_options.merge(@test_page)
      mock(AbCrunch::BestRun).of_avg_response_time(page[:num_baseline_runs], page)

      AbCrunch::StrategyBestConcurrency.run(@test_page)
    end

    it "should use page option overrides" do
      in_page = @test_page.merge({:num_baseline_runs => 17})
      expected_page = AbCrunch::Config.best_concurrency_options.merge(in_page)
      mock(AbCrunch::BestRun).of_avg_response_time(17, expected_page) {@fake_result}
      proxy(AbCrunch::Config.best_concurrency_options).merge(in_page)

      AbCrunch::StrategyBestConcurrency.run(in_page)
    end

    it "should find the max concurrency" do
      expected_page = AbCrunch::Config.best_concurrency_options.merge(@test_page)
      mock(AbCrunch::StrategyBestConcurrency).find_best_concurrency(expected_page, @fake_result) {@fake_result}

      AbCrunch::StrategyBestConcurrency.run(@test_page)
    end
  end

  describe "#calc_threshold" do
    describe "when max latency is higher than the base response time plus the percent margin" do
      it "should return the base response time plus the percent margin" do
        AbCrunch::StrategyBestConcurrency.calc_threshold(100, 0.2, 200).should == 120.0
      end
    end
    describe "when max latency is lower than the base response time plus the percent margin" do
      it "should return the max latency" do
        AbCrunch::StrategyBestConcurrency.calc_threshold(190, 0.2, 200).should == 200.0
      end
    end
  end
  
  describe "#find_best_concurrency" do
    before :each do
      @test_page = AbCrunchSpec.new_page({:num_requests => 50})
      @fake_result = AbCrunchSpec.new_result

      stub(AbCrunch::Logger).log
    end

    describe "when performance degrades" do
      it "should return the ab result for the run with the highest concurrency before response time degrades" do
        input_page = AbCrunch::Config.best_concurrency_options.merge(@test_page).merge({:num_concurrency_runs => 3})
        test_page_1 = input_page.clone.merge({:concurrency => 1})
        test_result_1 = @fake_result.clone
        test_result_1.ab_options = test_page_1

        test_page_2 = input_page.clone.merge({:concurrency => 2})
        test_result_2 = @fake_result.clone
        test_result_2.ab_options = test_page_2

        test_page_3 = input_page.clone.merge({:concurrency => 3})
        desired_result = @fake_result.clone
        desired_result.ab_options = test_page_3
        stub(desired_result).avg_response_time { 90.3 }

        test_page_4 = input_page.clone.merge({:concurrency => 4})
        degraded_result = @fake_result.clone
        degraded_result.ab_options = test_page_4
        stub(degraded_result).avg_response_time { 9999.3 }

        stub(AbCrunch::BestRun).of_avg_response_time(3, test_page_1) { test_result_1 }
        stub(AbCrunch::BestRun).of_avg_response_time(3, test_page_2) { test_result_2 }
        stub(AbCrunch::BestRun).of_avg_response_time(3, test_page_3) { desired_result }
        stub(AbCrunch::BestRun).of_avg_response_time(3, test_page_4) { degraded_result }

        result = AbCrunch::StrategyBestConcurrency.find_best_concurrency(input_page, @fake_result)

        result.ab_options[:concurrency].should == 3
        result.avg_response_time.should == 90.3
        result.should == desired_result
      end
    end

    describe "when concurrency exceeds num requests before performance degrades" do
      it "should return the latest result" do
        input_page = AbCrunch::Config.best_concurrency_options.merge(@test_page).merge({:num_concurrency_runs => 3, :num_requests => 3})
        test_page_1 = input_page.clone.merge({:concurrency => 1})
        test_result_1 = @fake_result.clone
        test_result_1.ab_options = test_page_1

        test_page_2 = input_page.clone.merge({:concurrency => 2})
        test_result_2 = @fake_result.clone
        test_result_2.ab_options = test_page_2

        test_page_3 = input_page.clone.merge({:concurrency => 3})
        desired_result = @fake_result.clone
        desired_result.ab_options = test_page_3
        stub(desired_result).avg_response_time { 90.3 }

        stub(AbCrunch::BestRun).of_avg_response_time(3, test_page_1) { test_result_1 }
        stub(AbCrunch::BestRun).of_avg_response_time(3, test_page_2) { test_result_2 }
        stub(AbCrunch::BestRun).of_avg_response_time(3, test_page_3) { desired_result }

        result = AbCrunch::StrategyBestConcurrency.find_best_concurrency(input_page, @fake_result)

        result.ab_options[:concurrency].should == 3
        result.avg_response_time.should == 90.3
        result.should == desired_result
      end
    end

  end

end