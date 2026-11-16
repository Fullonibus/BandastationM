import { type CSSProperties, useEffect } from 'react';
import { Color } from 'tgui-core/color';
import {
  Box,
  Button,
  Icon,
  NoticeBox,
  Section,
  Stack,
  StyleableSection,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import {
  DEPARTMENTS_RU,
  JOBS_RU,
  ReverseJobsRu,
} from '../bandastation/ru_jobs'; // BANDASTATION EDIT
import { Window } from '../layouts';
import { JOB2ICON } from './common/JobToIcon';

const JOIN_DISABLED_REASON = 'Вход в раунд временно отключён администрацией.';

type Job = {
  unavailable_reason: string | null;
  open_slots: number | '∞';
  used_slots: number;
  prioritized: BooleanLike;
  jobIcon: string;
  character_profile?: string;
  public_title?: string;
};

type JobDetails = {
  command: BooleanLike;
  description: string;
  job_icon?: string;
};

type Department = {
  jobs: Record<string, Job>;
  open_slots: number | '∞';
};

type DepartmentDetails = {
  color: string;
  jobs: Record<string, JobDetails>;
};

type Data = {
  departments_static: Record<string, DepartmentDetails>;
  departments: Record<string, Department>;
  alert_state: string;
  shuttle_status: string;
  disable_jobs_for_non_observers: BooleanLike;
  edit_slot: number;
  priority: BooleanLike;
  round_duration: string;
};

type JobEntryProps = {
  jobName: string;
  job: Job;
  details?: JobDetails;
  color: string;
  disabled: boolean;
  onClick: () => void;
};

function JobEntry(props: JobEntryProps) {
  const { jobName, job, details, color, disabled, onClick } = props;
  const jobIcon = job.jobIcon || JOB2ICON[ReverseJobsRu(jobName)];
  const title = job.public_title || JOBS_RU[jobName] || jobName;
  const unavailable = disabled || !!job.unavailable_reason;
  const departmentColor = Color.fromHex(color);
  const buttonStyle = {
    '--button-background': job.prioritized
      ? '#16fc0f'
      : departmentColor.lighten(10).toString(),
    '--button-background-disabled': '#b6b6b6',
    '--button-disabled-opacity': 1,
    '--button-color': unavailable
      ? '#242424'
      : departmentColor.darken(90).toString(),
    fontSize: '1.1rem',
  } as CSSProperties;

  return (
    <Button
      fluid
      disabled={unavailable}
      aria-disabled={unavailable}
      style={buttonStyle}
      tooltip={
        job.unavailable_reason ||
        (disabled && JOIN_DISABLED_REASON) ||
        (job.prioritized ? (
          <>
            <p style={{ marginTop: '0px' }}>
              <b>Глава персонала ищет сотрудников на эту должность.</b>
            </p>
            {details?.description}
          </>
        ) : (
          details?.description
        ))
      }
      tooltipPosition="top"
      onClick={onClick}
    >
      <Stack fill>
        {(details?.job_icon || jobIcon) && (
          <Stack.Item shrink={0}>
            {details?.job_icon ? (
              <img
                src={`data:image/png;base64,${details.job_icon}`}
                alt=""
                width={16}
                height={16}
                style={{ imageRendering: 'pixelated', marginRight: '0.1em' }}
              />
            ) : (
              <Icon style={{ marginRight: '0.1em' }} name={jobIcon} />
            )}
          </Stack.Item>
        )}
        <Stack.Item
          grow
          minWidth={0}
          style={{ whiteSpace: 'normal', overflowWrap: 'anywhere' }}
        >
          {details?.command ? <b>{title}</b> : title}
          {job.character_profile && (
            <Box fontSize={0.9}>{job.character_profile}</Box>
          )}
        </Stack.Item>
        <Stack.Item shrink={0} nowrap>
          {unavailable && <Icon name="lock" mr={0.5} aria-hidden />}
          {job.used_slots} / {job.open_slots}
        </Stack.Item>
      </Stack>
    </Button>
  );
}

type DepartmentEntryProps = {
  name: string;
  department: Department;
  details: DepartmentDetails;
};

function DepartmentEntry(props: DepartmentEntryProps) {
  const { name, department, details } = props;
  const { act, data } = useBackend<Data>();
  const { color } = details;
  const disabled = !!data.disable_jobs_for_non_observers;

  return (
    <Box minWidth="30%">
      <StyleableSection
        title={
          <Stack wrap align="baseline" justify="space-between" gr={0.5}>
            <Stack.Item minWidth={0} style={{ overflowWrap: 'anywhere' }}>
              {name}
            </Stack.Item>
            <Stack.Item fontSize={1} nowrap>
              позиций доступно: {disabled ? 0 : department.open_slots}
            </Stack.Item>
          </Stack>
        }
        style={{
          backgroundColor: color,
          marginBottom: '1em',
          breakInside: 'avoid-column',
        }}
        titleStyle={{
          borderBottomColor: Color.fromHex(color).darken(50).toString(),
        }}
        textStyle={{
          color: Color.fromHex(color).darken(90).toString(),
        }}
      >
        <Stack vertical>
          {Object.entries(department.jobs).map(([name, job]) => (
            <Stack.Item key={name}>
              <JobEntry
                key={name}
                jobName={name}
                job={job}
                details={details.jobs[name]}
                color={color}
                disabled={disabled}
                onClick={() =>
                  act('select_job', { job: name, edit_slot: data.edit_slot })
                }
              />
            </Stack.Item>
          ))}
        </Stack>
      </StyleableSection>
    </Box>
  );
}

export function JobSelection(props) {
  const { act, data } = useBackend<Data>();
  const ready = !!data?.departments_static && !!data.departments;
  useEffect(() => {
    if (ready) {
      act('ui_mounted_with_no_bluescreen');
    }
  }, [act, ready]);

  if (!ready) {
    return null; // Stop TGUI whitescreens with TGUI-dev!
  }

  const { departments, edit_slot, shuttle_status, round_duration } = data;
  const disabled = !!data.disable_jobs_for_non_observers;

  return (
    <Window width={1012} height={shuttle_status ? 690 : 666 /* Hahahahahaha */}>
      <Window.Content>
        <Section
          fill
          scrollable
          title={
            <>
              {shuttle_status && <NoticeBox info>{shuttle_status}</NoticeBox>}
              {disabled && <NoticeBox danger>{JOIN_DISABLED_REASON}</NoticeBox>}
              <Stack wrap align="center" justify="space-between">
                <Stack.Item color="label">
                  Время с начала смены: {round_duration}
                </Stack.Item>
                <Stack.Item>
                  <Button
                    disabled={disabled}
                    aria-disabled={disabled}
                    fontWeight="normal"
                    onClick={() =>
                      act('select_job', { job: 'Random', edit_slot })
                    }
                    tooltip={
                      disabled
                        ? JOIN_DISABLED_REASON
                        : 'Случайно выбрать профессию. Вы можете повторно выбирать случайную профессию или отказаться от этого.'
                    }
                  >
                    Случайная профессия!
                  </Button>
                </Stack.Item>
              </Stack>
            </>
          }
        >
          <Box style={{ columns: '20em' }}>
            {Object.entries(departments).map(([name, department]) => {
              const details = data.departments_static[name];
              return (
                details &&
                Object.keys(department.jobs).length > 0 && (
                  <DepartmentEntry
                    key={name}
                    name={DEPARTMENTS_RU[name] || name}
                    department={department}
                    details={details}
                  />
                )
              );
            })}
          </Box>
        </Section>
      </Window.Content>
    </Window>
  );
}
