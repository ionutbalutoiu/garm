package e2e

import (
	"fmt"
	"log"
	"time"

	commonParams "github.com/cloudbase/garm-provider-common/params"
	"github.com/cloudbase/garm/params"
)

func ValidateJobLifecycle(label string) {
	log.Printf("Validate GARM job lifecycle with label %s", label)

	// wait for job list to be updated
	job, err := waitLabelledJob(label, 4*time.Minute)
	if err != nil {
		panic(err)
	}

	// check expected job status
	job, err = waitJobStatus(job.ID, params.JobStatusQueued, 4*time.Minute)
	if err != nil {
		panic(err)
	}
	job, err = waitJobStatus(job.ID, params.JobStatusInProgress, 4*time.Minute)
	if err != nil {
		panic(err)
	}

	// check expected instance status
	instance, err := waitInstanceStatus(job.RunnerName, commonParams.InstanceRunning, params.RunnerActive, 5*time.Minute)
	if err != nil {
		panic(err)
	}

	// wait for job to be completed
	_, err = waitJobStatus(job.ID, params.JobStatusCompleted, 4*time.Minute)
	if err != nil {
		panic(err)
	}

	// wait for instance to be removed
	err = waitInstanceToBeRemoved(instance.Name, 5*time.Minute)
	if err != nil {
		panic(err)
	}

	// wait for GARM to rebuild the pool running idle instances
	err = waitPoolRunningIdleInstances(instance.PoolID, 6*time.Minute)
	if err != nil {
		panic(err)
	}
}

func waitLabelledJob(label string, timeout time.Duration) (*params.Job, error) {
	var timeWaited time.Duration = 0
	var jobs params.Jobs
	var err error

	log.Printf("Waiting for job with label %s", label)
	for timeWaited < timeout {
		jobs, err = listJobs(cli, authToken)
		if err != nil {
			return nil, err
		}
		for _, job := range jobs {
			for _, jobLabel := range job.Labels {
				if jobLabel == label {
					return &job, err
				}
			}
		}
		time.Sleep(5 * time.Second)
		timeWaited += 5 * time.Second
	}

	if err := printJsonResponse(jobs); err != nil {
		return nil, err
	}
	return nil, fmt.Errorf("failed to wait job with label %s", label)
}

func waitJobStatus(id int64, status params.JobStatus, timeout time.Duration) (*params.Job, error) {
	var timeWaited time.Duration = 0
	var job *params.Job

	log.Printf("Waiting for job %d to reach status %s", id, status)
	for timeWaited < timeout {
		jobs, err := listJobs(cli, authToken)
		if err != nil {
			return nil, err
		}

		job = nil
		for _, j := range jobs {
			if j.ID == id {
				job = &j
				break
			}
		}

		if job == nil {
			if status == params.JobStatusCompleted {
				// The job is not found in the list. We can safely assume
				// that it is completed
				return nil, nil
			}
			// if the job is not found, and expected status is not "completed",
			// we need to error out.
			return nil, fmt.Errorf("job %d not found, expected to be found in status %s", id, status)
		} else if job.Status == string(status) {
			return job, nil
		}
		time.Sleep(5 * time.Second)
		timeWaited += 5 * time.Second
	}

	if err := printJsonResponse(*job); err != nil {
		return nil, err
	}
	return nil, fmt.Errorf("timeout waiting for job %d to reach status %s", id, status)
}
