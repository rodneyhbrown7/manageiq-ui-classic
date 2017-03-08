describe MiqTaskController do
  context "#tasks_condition" do
    let(:user) { FactoryGirl.create(:user) }
    subject { controller.send(:tasks_condition, @opts) }
    before do
      allow(controller).to receive_messages(:session => user)
    end

    describe "My VM and Container Analysis Tasks" do
      before do
        controller.instance_variable_set(:@tabform, "tasks_1")
        @opts = {:ok           => true,
                 :queued       => true,
                 :error        => true,
                 :warn         => true,
                 :running      => true,
                 :state_choice => "all",
                 :zone         => "<all>",
                 :time_period  => 0,
                 :states       => [%w(Initializing initializing),
                                   %w(Waiting to Start waiting_to_start),
                                   %w(Cancelling cancelling),
                                   %w(Aborting aborting),
                                   %w(Finished finished),
                                   %w(Snapshot\ Create snapshot_create),
                                   %w(Scanning scanning),
                                   %w(Snapshot\ Delete snapshot_delete),
                                   %w(Synchronizing synchronizing),
                                   %w(Deploy\ Smartproxy deploy_smartproxy)]
        }
      end

      it "all defaults" do
        query = "jobs.userid=? AND "\
                "((jobs.state=? OR jobs.state=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state!=? AND jobs.state!=? AND jobs.state!=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=?"
        expected = [query,
                    user.userid,
                    "waiting_to_start", "Queued",
                    "finished", "ok",
                    "finished", "error",
                    "finished", "warn",
                    "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period])
        expect(subject).to eq(expected)
      end

      it "Zone: default, Time period: 1 Day Ago, status:  Ok, State:  Finished" do
        set_opts(:queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "finished",
                 :zone         => "default",
                 :time_period  => 1)

        query = "jobs.userid=? AND "\
                "((jobs.state=? AND jobs.status=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.zone=? AND "\
                "jobs.state=?"
        expected = [query,
                    user.userid,
                    "finished", "ok"]
        expected += get_time_period(@opts[:time_period]) << "default" << "finished"
        expect(subject).to eq(expected)
      end

      it "zone: default, Time period: 6 Days Ago, status: Error and Warn, State: All " do
        set_opts(:ok          => nil,
                 :queued      => nil,
                 :error       => "1",
                 :warn        => "1",
                 :running     => nil,
                 :zone        => "default",
                 :time_period => 6)

        query = "jobs.userid=? AND ("\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.zone=?"
        expected = [query,
                    user.userid,
                    "finished", "error",
                    "finished", "warn"]
        expected += get_time_period(@opts[:time_period]) << "default"
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: Last 24, Status: Queued, Running, Ok, Error and Warn, State: Aborting" do
        set_opts(:state_choice => "aborting")

        query = "jobs.userid=? AND "\
                "((jobs.state=? OR jobs.state=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state!=? AND jobs.state!=? AND jobs.state!=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.state=?"
        expected = [query,
                    user.userid,
                    "waiting_to_start", "Queued",
                    "finished", "ok",
                    "finished", "error",
                    "finished", "warn",
                    "finished", "waiting_to_start", "queued"]

        expected += get_time_period(@opts[:time_period]) << "aborting"
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: Last 24, Status: none, State: All" do
        set_opts(:ok      => nil,
                 :queued  => nil,
                 :error   => nil,
                 :warn    => nil,
                 :running => nil)

        query = "jobs.userid=? AND "\
                "(jobs.status!=? AND jobs.status!=? AND jobs.status!=? AND jobs.state!=? AND jobs.state!=?) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=?"

        expected = [query,
                    user.userid,
                    "ok", "error", "warn", "finished", "waiting_to_start"]

        expected += get_time_period(@opts[:time_period])
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: Last 24, Status: none, State: Aborting" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "aborting")

        query = "jobs.userid=? AND "\
                "(jobs.status!=? AND jobs.status!=? AND jobs.status!=? AND jobs.state!=? AND jobs.state!=?) "\
                "AND jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.state=?"

        expected = [query, user.userid, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "aborting"
        expect(subject).to eq(expected)
      end

      it "zone: default, Time period: 1 Day Ago, Status: none, State: Waiting to Start" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "waiting_to_start",
                 :zone         => "default",
                 :time_period  => 1)

        query = "jobs.userid=? AND "\
                "(jobs.status!=? AND jobs.status!=? AND jobs.status!=? AND jobs.state!=? AND jobs.state!=?) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.zone=? AND "\
                "jobs.state=?"
        expected = [query, user.userid, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "default" << "waiting_to_start"
        expect(subject).to eq(expected)
      end

      it "zone: default, Time period: 4 Days Ago, Status: Queued and Running, State: Synchronizing" do
        set_opts(:ok           => nil,
                 :queued       => "1",
                 :error        => nil,
                 :warn         => nil,
                 :running      => "1",
                 :state_choice => "synchronizing",
                 :zone         => "default",
                 :time_period  => 4)

        query = "jobs.userid=? AND "\
                "((jobs.state=? OR jobs.state=?) OR "\
                "(jobs.state!=? AND jobs.state!=? AND jobs.state!=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.zone=? AND "\
                "jobs.state=?"
        expected = [query, user.userid, "waiting_to_start", "Queued", "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period]) << "default" << "synchronizing"
        expect(subject).to eq(expected)
      end

      it "zone: default, Time period: 4 Days Ago, Status: Queued and Running, State: Snapshot Delete" do
        set_opts(:ok           => nil,
                 :queued       => "1",
                 :error        => nil,
                 :warn         => nil,
                 :running      => "1",
                 :state_choice => "snapshot_delete",
                 :zone         => "default",
                 :time_period  => 4)

        query = "jobs.userid=? AND "\
                "((jobs.state=? OR jobs.state=?) OR "\
                "(jobs.state!=? AND jobs.state!=? AND jobs.state!=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.zone=? AND "\
                "jobs.state=?"
        expected = [query, user.userid, "waiting_to_start", "Queued", "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period]) << "default" << "snapshot_delete"
        expect(subject).to eq(expected)
      end
    end

    describe "My Other UI Tasks" do
      before do
        controller.instance_variable_set(:@tabform, "tasks_2")
        @opts = {:ok           => true,
                 :queued       => true,
                 :error        => true,
                 :warn         => true,
                 :running      => true,
                 :state_choice => "all",
                 :time_period  => 0,
                 :states       => [%w(Initialized Initialized),
                                   %w(Queued Queued),
                                   %w(Active Active),
                                   %w(Finished Finished)]
        }
      end

      it "all defaults" do
        query = 'jobs.guid IS NULL AND miq_tasks.userid=? AND ('\
                '(miq_tasks.state=? OR miq_tasks.state=?) OR '\
                '(miq_tasks.state=? AND miq_tasks.status=?) OR '\
                '(miq_tasks.state=? AND miq_tasks.status=?) OR '\
                '(miq_tasks.state=? AND miq_tasks.status=?) OR '\
                '(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND '\
                'miq_tasks.updated_on>=? AND '\
                'miq_tasks.updated_on<=?'
        expected = [query, user.userid, "waiting_to_start", "Queued", "Finished", "Ok",
                    "Finished", "Error", "Finished", "Warn", "Finished", "waiting_to_start", "Queued"
                   ]
        expected += get_time_period(@opts[:time_period])
        expect(subject).to eq(expected)
      end

      it "Time period: 6 Days ago, status: queued and running, state: initialized" do
        set_opts(:ok           => nil,
                 :error        => nil,
                 :warn         => nil,
                 :state_choice => "Initialized",
                 :time_period  => 6)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND ("\
                "(miq_tasks.state=? OR miq_tasks.state=?) OR "\
                "(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "waiting_to_start", "Queued", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Initialized"
        expect(subject).to eq(expected)
      end

      it "Time period: 6 Days Ago, status: queued and running, state: active" do
        set_opts(:ok           => nil,
                 :error        => nil,
                 :warn         => nil,
                 :state_choice => "Active",
                 :time_period  => 6)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "((miq_tasks.state=? OR miq_tasks.state=?) OR "\
                "(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "waiting_to_start", "Queued", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Active"
        expect(subject).to eq(expected)
      end

      it "Time period: 6 Days Ago, status: queued and running, state: finished" do
        set_opts(:ok => nil, :error => nil, :warn => nil, :state_choice => "Finished", :time_period => 6)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "((miq_tasks.state=? OR miq_tasks.state=?) OR "\
                "(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "waiting_to_start", "Queued", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Finished"
        expect(subject).to eq(expected)
      end

      it "Time period: 6 Days Ago, status: ok, state: queued" do
        set_opts(:ok           => "1",
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "Queued",
                 :time_period  => 6)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "((miq_tasks.state=? AND miq_tasks.status=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"

        expected = [query, user.userid, "Finished", "Ok"]
        expected += get_time_period(@opts[:time_period]) << "Queued"
        expect(subject).to eq(expected)
      end

      it "Time period: 6 Days Ago, status: ok and warn, state: queued" do
        set_opts(:ok           => "1",
                 :queued       => nil,
                 :error        => nil,
                 :warn         => "1",
                 :running      => nil,
                 :state_choice => "Queued",
                 :time_period  => 6)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "((miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "Finished", "Ok", "Finished", "Warn"]
        expected += get_time_period(@opts[:time_period]) << "Queued"
        expect(subject).to eq(expected)
      end

      it "Time period: 6 Days Ago, status: ok and warn and error, state: queued" do
        set_opts(:ok           => "1",
                 :queued       => nil,
                 :error        => "1",
                 :warn         => "1",
                 :running      => nil,
                 :state_choice => "Queued",
                 :time_period  => 6)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "((miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "Finished", "Ok", "Finished", "Error", "Finished", "Warn"]
        expected += get_time_period(@opts[:time_period]) << "Queued"
        expect(subject).to eq(expected)
      end

      it "Time Period: Last 24, Status: none checked, State: All" do
        set_opts(:ok => nil, :queued => nil, :error => nil, :warn => nil, :running => nil)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "(miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.state!=? AND "\
                "miq_tasks.state!=?) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=?"
        expected = [query, user.userid, "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period])
        expect(subject).to eq(expected)
      end

      it "Time Period: Last 24, Status: none checked, State: Active" do
        set_opts(:ok => nil, :queued => nil, :error => nil, :warn => nil, :running => nil, :state_choice => "Active")

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "(miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.state!=? AND "\
                "miq_tasks.state!=?) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Active"
        expect(subject).to eq(expected)
      end

      it "Time Period: 1 Day Ago, Status: none checked, State: Finished" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "Finished",
                 :time_period  => 1)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "(miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.state!=? AND "\
                "miq_tasks.state!=?) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Finished"
        expect(subject).to eq(expected)
      end

      it "Time Period: 2 Day Ago, Status: none checked, State: Initialized" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "Initialized",
                 :time_period  => 2)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "(miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.state!=? AND "\
                "miq_tasks.state!=?) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Initialized"
        expect(subject).to eq(expected)
      end

      it "Time Period: 3 Day Ago, Status: none checked, State: Queued" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "Queued",
                 :time_period  => 3)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "(miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.state!=? AND "\
                "miq_tasks.state!=?) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, user.userid, "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Queued"
        expect(subject).to eq(expected)
      end
    end

    describe "All VM and Container Analysis Tasks" do
      before do
        controller.instance_variable_set(:@tabform, "tasks_3")
        @opts = {:ok           => true,
                 :queued       => true,
                 :error        => true,
                 :warn         => true,
                 :running      => true,
                 :state_choice => "all",
                 :zone         => "<all>",
                 :user_choice  => "all",
                 :time_period  => 0,
                 :states       => [%w(Initializing initializing),
                                   %w(Waiting to Start waiting_to_start),
                                   %w(Cancelling cancelling),
                                   %w(Aborting aborting),
                                   %w(Finished finished),
                                   %w(Snapshot\ Create snapshot_create),
                                   %w(Scanning scanning),
                                   %w(Snapshot\ Delete snapshot_delete),
                                   %w(Synchronizing synchronizing),
                                   %w(Deploy\ Smartproxy deploy_smartproxy)]
                }
      end

      it "all defaults" do
        query = "((jobs.state=? OR jobs.state=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state!=? AND jobs.state!=? AND jobs.state!=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=?"
        expected = [query, "waiting_to_start", "Queued", "finished", "ok", "finished", "error",
                    "finished", "warn", "finished", "waiting_to_start", "queued"
                   ]
        expected += get_time_period(@opts[:time_period])
        expect(subject).to eq(expected)
      end

      it "zone: default, user: all, Time  period: 6 Days Ago, status: queued and running, state: all" do
        set_opts(:ok => nil, :queued => "1", :error => nil, :warn => nil, :zone => "default", :time_period => 6)

        query = "((jobs.state=? OR jobs.state=?) OR "\
                "(jobs.state!=? AND jobs.state!=? AND jobs.state!=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.zone=?"
        expected = [query, "waiting_to_start", "Queued", "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period]) << "default"
        expect(subject).to eq(expected)
      end

      it "zone: default, user: all, Time period: 6 Days Ago, status: queued and running, state: snapshot create" do
        set_opts(:ok           => nil,
                 :queued       => "1",
                 :error        => nil,
                 :warn         => nil,
                 :state_choice => "snapshot_create",
                 :zone         => "default",
                 :time_period  => 6)

        query = "((jobs.state=? OR jobs.state=?) OR "\
                "(jobs.state!=? AND jobs.state!=? AND jobs.state!=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.zone=? AND "\
                "jobs.state=?"
        expected = [query, "waiting_to_start", "Queued", "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period]) << "default" << "snapshot_create"
        expect(subject).to eq(expected)
      end

      it "zone: default, user: all, Time period: 6 Days Ago, status: queued and running and ok, state: snapshot create" do
        set_opts(:ok           => "1",
                 :queued       => "1",
                 :error        => nil,
                 :warn         => nil,
                 :state_choice => "snapshot_create",
                 :zone         => "default",
                 :time_period  => 6)

        query = "((jobs.state=? OR jobs.state=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state!=? AND jobs.state!=? AND jobs.state!=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.zone=? AND "\
                "jobs.state=?"
        expected = [query, "waiting_to_start", "Queued", "finished", "ok",
                    "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period]) << "default" << "snapshot_create"
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: Last 24, Status: none checked, State: Snapshot Create" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "snapshot_create")

        query = "(jobs.status!=? AND jobs.status!=? AND jobs.status!=? AND jobs.state!=? AND jobs.state!=?) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.state=?"
        expected = [query, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "snapshot_create"
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: 2 Days Ago, Status: none checked, State: Scanning" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "scanning",
                 :time_period  => 2)

        query = "(jobs.status!=? AND jobs.status!=? AND jobs.status!=? AND jobs.state!=? AND jobs.state!=?) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.state=?"
        expected = [query, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "scanning"
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: 3 Days Ago, Status: none checked, State: Initializing" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "initializing",
                 :time_period  => 3)

        query = "(jobs.status!=? AND jobs.status!=? AND jobs.status!=? AND jobs.state!=? AND jobs.state!=?) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.state=?"
        expected = [query, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "initializing"
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: 4 Days Ago, Status: none checked, State: Finished" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "finished",
                 :time_period  => 4)

        query = "(jobs.status!=? AND jobs.status!=? AND jobs.status!=? AND jobs.state!=? AND jobs.state!=?) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.state=?"
        expected = [query, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "finished"
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: 5 Days Ago, Status: none checked, State: Deploy Smartproxy" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "deploy_smartproxy",
                 :time_period  => 5)

        query = "(jobs.status!=? AND jobs.status!=? AND jobs.status!=? AND jobs.state!=? AND jobs.state!=?) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.state=?"
        expected = [query, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "deploy_smartproxy"
        expect(subject).to eq(expected)
      end

      it "zone: <All Zones>, Time period: 6 Days Ago, Status: Ok, Error and Warn, State: Cancelling" do
        set_opts(:ok           => "1",
                 :queued       => nil,
                 :error        => "1",
                 :warn         => "1",
                 :running      => nil,
                 :state_choice => "cancelling",
                 :time_period  => 6)

        query = "((jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?) OR "\
                "(jobs.state=? AND jobs.status=?)) AND "\
                "jobs.updated_on>=? AND "\
                "jobs.updated_on<=? AND "\
                "jobs.state=?"
        expected = [query, "finished", "ok", "finished", "error", "finished", "warn"]
        expected += get_time_period(@opts[:time_period]) << "cancelling"
        expect(subject).to eq(expected)
      end
    end

    describe "All Other Tasks" do
      before do
        controller.instance_variable_set(:@tabform, "tasks_4")

        @opts = {:ok           => true,
                 :queued       => true,
                 :error        => true,
                 :warn         => true,
                 :running      => true,
                 :state_choice => "all",
                 :user_choice  => "all",
                 :time_period  => 0,
                 :states       => [%w(Initialized Initialized),
                                   %w(Queued Queued),
                                   %w(Active Active),
                                   %w(Finished Finished)]

        }
      end

      it "all defaults" do
        query = "jobs.guid IS NULL AND ((miq_tasks.state=? OR miq_tasks.state=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=?"
        expected = [query, "waiting_to_start", "Queued", "Finished", "Ok", "Finished", "Error",
                    "Finished", "Warn", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period])
        expect(subject).to eq(expected)
      end

      it "user: all, Time period: 1 Day Ago, status: queued, running, ok, error and warn, state: active" do
        set_opts(:state_choice => "Active", :time_period => 1)

        query = "jobs.guid IS NULL AND ((miq_tasks.state=? OR miq_tasks.state=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, "waiting_to_start", "Queued", "Finished", "Ok", "Finished", "Error",
                    "Finished", "Warn", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Active"
        expect(subject).to eq(expected)
      end

      it "user: all, Time period: 1 Day Ago, status: queued, running, ok, error and warn, state: finished" do
        set_opts(:state_choice => "Finished", :time_period => 1)

        query = "jobs.guid IS NULL AND ((miq_tasks.state=? OR miq_tasks.state=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, "waiting_to_start", "Queued", "Finished", "Ok", "Finished", "Error",
                    "Finished", "Warn", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Finished"
        expect(subject).to eq(expected)
      end

      it "user: all, Time period: 1 Day Ago, status: queued, running, ok, error and warn, state: initialized" do
        set_opts(:state_choice => "Initialized", :time_period => 1)

        query = "jobs.guid IS NULL AND ((miq_tasks.state=? OR miq_tasks.state=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND miq_tasks.state=?"
        expected = [query, "waiting_to_start", "Queued", "Finished", "Ok", "Finished", "Error",
                    "Finished", "Warn", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Initialized"
        expect(subject).to eq(expected)
      end

      it "user: all, Time period: 1 Day Ago, status: queued, running, ok, error and warn, state: queued" do
        set_opts(:state_choice => "Queued", :time_period => 1)

        query = "jobs.guid IS NULL AND ((miq_tasks.state=? OR miq_tasks.state=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state=? AND miq_tasks.status=?) OR "\
                "(miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, "waiting_to_start", "Queued", "Finished", "Ok", "Finished", "Error",
                    "Finished", "Warn", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Queued"
        expect(subject).to eq(expected)
      end

      it "User: All Users, Time Period: Last 24, Status: none checked, State: All" do
        set_opts(:ok => nil, :queued => nil, :error => nil, :warn => nil, :running => nil)

        query = "jobs.guid IS NULL AND (miq_tasks.status!=? AND miq_tasks.status!=? AND "\
                "miq_tasks.status!=? AND miq_tasks.state!=? AND miq_tasks.state!=?) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=?"
        expected = [query, "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period])
        expect(subject).to eq(expected)
      end

      it "User: system, Time Period: 1 Day Ago, Status: none checked, State: Active" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "Active",
                 :user_choice  => "system",
                 :time_period  => 1)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "(miq_tasks.status!=? AND miq_tasks.status!=? AND miq_tasks.status!=? AND "\
                "miq_tasks.state!=? AND miq_tasks.state!=?) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, "system", "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Active"
        expect(subject).to eq(expected)
      end

      it "User: system, Time Period: 2 Day Ago, Status: Queued, State: Finished" do
        set_opts(:ok           => nil,
                 :queued       => "1",
                 :error        => nil,
                 :warn         => nil,
                 :running      => nil,
                 :state_choice => "Finished",
                 :user_choice  => "system",
                 :time_period  => 2)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "((miq_tasks.state=? OR miq_tasks.state=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, "system", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Finished"
        expect(subject).to eq(expected)
      end

      it "User: system, Time Period: 3 Day Ago, Status: Running, State: Initialized" do
        set_opts(:ok           => nil,
                 :queued       => nil,
                 :error        => nil,
                 :warn         => nil,
                 :running      => "1",
                 :state_choice => "Initialized",
                 :user_choice  => "system",
                 :time_period  => 3)

        query = "jobs.guid IS NULL AND miq_tasks.userid=? AND "\
                "((miq_tasks.state!=? AND miq_tasks.state!=? AND miq_tasks.state!=?)) AND "\
                "miq_tasks.updated_on>=? AND "\
                "miq_tasks.updated_on<=? AND "\
                "miq_tasks.state=?"
        expected = [query, "system", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Initialized"
        expect(subject).to eq(expected)
      end
    end

    describe "building tabs" do
      before(:each) do
        controller.instance_variable_set(:@tabform, "ui_2")
        controller.instance_variable_set(:@settings, :perpage => {})
        allow(controller).to receive(:role_allows?).and_return(true)
      end

      it 'sets the available tabs' do
        controller.build_jobs_tab
        expect(assigns(:tabs)).to eq([
                                       ["1", _("My VM and Container Analysis Tasks")],
                                       ["2", _("My Other UI Tasks")],
                                       ["3", _("All VM and Container Analysis Tasks")],
                                       ["4", _("All Other Tasks")]
                                     ])
      end
    end

    describe "#list_jobs" do
      it 'sets the active tab' do
        controller.instance_variable_set(:@tabform, "ui_2")
        controller.instance_variable_set(:@tasks_options, {})
        allow(controller).to receive(:tasks_condition)
        allow(controller).to receive(:get_view)
        controller.list_jobs
        expect(assigns(:active_tab)).to eq("2")
      end
    end

    def get_time_period(period)
      t = format_timezone(period.to_i != 0 ? period.days.ago : Time.now, Time.zone, "raw")
      ret = []
      ret << t.beginning_of_day << t.end_of_day
    end

    def set_opts(hsh)
      hsh.each_pair { |k, v| @opts[k] = v }
    end
  end
end
