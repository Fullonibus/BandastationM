import { useState } from 'react';
import {
	Box,
	Button,
	Icon,
	Input,
	NoticeBox,
	ProgressBar,
	Section,
	Stack,
	Table,
	Tabs,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Objective = {
	text: string;
	completed: boolean | null;
	context?: string | null;
};

type Antagonist = {
	antag_ref: string;
	key: string;
	ckey: string | null;
	char_name: string;
	role: string;
	team: string | null;
	status: 'alive' | 'dead' | 'no_client' | 'body_destroyed';
	objectives: Objective[];
	outcome: number;
	mob_ref: string | null;
	mind_ref: string | null;
};

type Category = {
	name: string;
	total: number;
	wins: number;
	losses: number;
	unconditional: number;
	winrate: number | null;
	antagonists: Antagonist[];
};

type TeamMember = {
	key: string;
	ckey: string | null;
	name: string;
	alive: boolean;
	stat: number;
	mob_ref: string | null;
	mind_ref: string | null;
};

type AntagTeam = {
	name: string;
	members_count: number;
	members_alive?: number;
	members?: TeamMember[];
	objectives: Objective[];
	outcome: number;
};

type Summary = {
	total: number;
	wins: number;
	losses: number;
	unconditional: number;
	winrate: number | null;
};

type HistoryRound = {
	round_id: number;
	datetime: string;
	total: number;
	wins: number;
	losses: number;
	winrate: number | null;
};

type HistoryRole = {
	name: string;
	total: number;
	wins: number;
	losses: number;
	winrate: number | null;
};

type HistoryData = {
	total_rounds: number;
	total_antags: number;
	total_wins: number;
	total_losses: number;
	overall_winrate: number | null;
	roles: HistoryRole[];
	rounds: HistoryRound[];
};

type AntagWinLossData = {
	round_started: boolean;
	summary: Summary;
	categories: Category[];
	teams: AntagTeam[];
	can_view_variables: boolean;
	history: HistoryData | null;
	history_limit: number;
	history_status: 'idle' | 'loading' | 'ready' | 'unavailable' | 'error';
};

type RoleSortField = 'name' | 'total' | 'wins' | 'losses' | 'winrate';

function OutcomeBadge({ outcome }: { outcome: number }) {
	if (outcome === 1) {
		return (
			<Button
				compact
				color="good"
				style={{
					pointerEvents: 'none',
					cursor: 'default',
					minWidth: '85px',
					textAlign: 'center',
					margin: 0,
				}}
			>
				Победа
			</Button>
		);
	}
	if (outcome === 0) {
		return (
			<Button
				compact
				color="bad"
				style={{
					pointerEvents: 'none',
					cursor: 'default',
					minWidth: '85px',
					textAlign: 'center',
					margin: 0,
				}}
			>
				Поражение
			</Button>
		);
	}
	return (
		<Button
			compact
			color="default"
			style={{
				pointerEvents: 'none',
				cursor: 'default',
				minWidth: '85px',
				textAlign: 'center',
				margin: 0,
			}}
		>
			Без условий
		</Button>
	);
}

function StatusBadge({ status }: { status: Antagonist['status'] }) {
	switch (status) {
		case 'alive':
			return (
				<Box color="good" bold>
					<Icon name="heartbeat" mr={0.5} />
					Жив
				</Box>
			);
		case 'dead':
			return (
				<Box color="bad" bold>
					<Icon name="skull" mr={0.5} />
					Мёртв
				</Box>
			);
		case 'no_client':
			return (
				<Box color="orange" bold>
					<Icon name="plug" mr={0.5} />
					Нет клиента
				</Box>
			);
		case 'body_destroyed':
			return (
				<Box color="bad" bold>
					<Icon name="times-circle" mr={0.5} />
					Тело уничтожено
				</Box>
			);
		default:
			return <Box color="label">—</Box>;
	}
}

function ObjectiveItem({ objective }: { objective: Objective }) {
	const { completed } = objective;
	return (
		<Box
			color={completed === null ? 'label' : completed ? 'good' : 'bad'}
			fontSize="11px"
		>
			<Icon
				name={
					completed === null
						? 'minus-circle'
						: completed
							? 'check-circle'
							: 'times-circle'
				}
				mr={0.5}
			/>
			<span>{objective.text}</span>
			{objective.context ? (
				<Box
					as="span"
					color="label"
					fontSize="10px"
					ml={0.5}
					style={{ fontStyle: 'italic' }}
				>
					({objective.context})
				</Box>
			) : null}
		</Box>
	);
}

function HistoryRefreshButton({
	loading,
	onRefresh,
}: {
	loading: boolean;
	onRefresh: () => void;
}) {
	return (
		<Button
			icon="sync"
			iconSpin={loading}
			disabled={loading}
			compact
			width="195px"
			textAlign="center"
			tooltip={
				loading
					? 'Загрузка данных из базы данных...'
					: 'Запросить свежие данные из базы данных'
			}
			onClick={onRefresh}
		>
			{loading ? 'Загрузка данных...' : 'Обновить данные из БД'}
		</Button>
	);
}

export function AntagWinLossPanel() {
	const { act, data } = useBackend<AntagWinLossData>();
	const [activeTab, setActiveTab] = useState<'current' | 'history'>('current');
	const [searchQuery, setSearchQuery] = useState('');
	const [filterStatus, setFilterStatus] = useState<
		'all' | 'alive' | 'dead' | 'win' | 'loss' | 'unconditional'
	>('all');
	const [roleSortKey, setRoleSortKey] = useState<RoleSortField>('total');
	const [roleSortAsc, setRoleSortAsc] = useState<boolean>(false);

	const {
		round_started = false,
		summary = {
			total: 0,
			wins: 0,
			losses: 0,
			unconditional: 0,
			winrate: null,
		},
		categories = [],
		teams = [],
		can_view_variables = false,
		history = null,
		history_limit = 25,
		history_status = 'idle',
	} = data;

	const query = searchQuery.trim().toLowerCase();

	const filterAntagonist = (antag: Antagonist): boolean => {
		if (
			filterStatus === 'alive' &&
			antag.status !== 'alive' &&
			antag.status !== 'no_client'
		) {
			return false;
		}
		if (
			filterStatus === 'dead' &&
			antag.status !== 'dead' &&
			antag.status !== 'body_destroyed'
		) {
			return false;
		}
		if (filterStatus === 'win' && antag.outcome !== 1) {
			return false;
		}
		if (filterStatus === 'loss' && antag.outcome !== 0) {
			return false;
		}
		if (filterStatus === 'unconditional' && antag.outcome !== -1) {
			return false;
		}

		if (query) {
			const keyMatch = antag.key.toLowerCase().includes(query);
			const ckeyMatch = antag.ckey ? antag.ckey.toLowerCase().includes(query) : false;
			const charMatch = antag.char_name.toLowerCase().includes(query);
			const roleMatch = antag.role.toLowerCase().includes(query);
			if (!keyMatch && !ckeyMatch && !charMatch && !roleMatch) {
				return false;
			}
		}

		return true;
	};

	const filteredCategories = categories
		.map((category) => ({
			...category,
			antagonists: category.antagonists.filter(filterAntagonist),
		}))
		.filter((category) => category.antagonists.length > 0);

	const matchedCount = filteredCategories.reduce(
		(acc, cat) => acc + cat.antagonists.length,
		0
	);

	const handleRoleSort = (key: RoleSortField) => {
		if (roleSortKey === key) {
			setRoleSortAsc(!roleSortAsc);
		} else {
			setRoleSortKey(key);
			setRoleSortAsc(key === 'name');
		}
	};

	const sortedRoles = history?.roles
		? [...history.roles].sort((a, b) => {
			const aVal = a[roleSortKey];
			const bVal = b[roleSortKey];
			if (aVal === bVal) return 0;
			if (aVal === null || aVal === undefined) return 1;
			if (bVal === null || bVal === undefined) return -1;
			if (typeof aVal === 'string' && typeof bVal === 'string') {
				return roleSortAsc ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
			}
			return roleSortAsc
				? (aVal as number) - (bVal as number)
				: (bVal as number) - (aVal as number);
		})
		: [];

	return (
		<Window title="Статистика антагонистов" width={920} height={660}>
			<Window.Content scrollable>
				<Tabs mb={1.5}>
					<Tabs.Tab
						icon="user-secret"
						selected={activeTab === 'current'}
						onClick={() => setActiveTab('current')}
					>
						Текущий раунд
					</Tabs.Tab>
					<Tabs.Tab
						icon="database"
						selected={activeTab === 'history'}
						onClick={() => {
						setActiveTab('history');
						if (history_status === 'idle') {
							act('load_history');
						}
					}}
					>
						История (БД)
					</Tabs.Tab>
				</Tabs>

				{activeTab === 'current' && (
					<Button
						icon="sync"
						compact
						mb={1}
						onClick={() => act('refresh_current')}
					>
						Обновить текущий раунд
					</Button>
				)}

				{activeTab === 'current' &&
					(!round_started ? (
						<NoticeBox danger mb={1.5}>
							<b>Раунд ещё не начался.</b> Список антагонистов пуст до начала смены.
						</NoticeBox>
					) : summary.total === 0 ? (
						<NoticeBox info mb={1.5}>
							В текущем раунде антагонисты пока не найдены.
						</NoticeBox>
					) : (
						<>
							<Section title="Сводка по текущему раунду" mb={1.5}>
									<Stack g={1} mb={1.5}>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													ВСЕГО АНТАГОНИСТОВ
												</Box>
												<Box fontSize="22px" bold color="blue">
													{summary.total}
												</Box>
											</Box>
										</Stack.Item>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													ПОБЕД
												</Box>
												<Box fontSize="22px" bold color="good">
													{summary.wins}
												</Box>
											</Box>
										</Stack.Item>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													ПОРАЖЕНИЙ
												</Box>
												<Box fontSize="22px" bold color="bad">
													{summary.losses}
												</Box>
											</Box>
										</Stack.Item>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													БЕЗ УСЛОВИЙ
												</Box>
												<Box fontSize="22px" bold color="average">
													{summary.unconditional}
												</Box>
											</Box>
										</Stack.Item>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													ДОЛЯ ПОБЕД
												</Box>
												<Box
													fontSize="22px"
													bold
													color={
														summary.winrate === null
															? 'label'
															: summary.winrate >= 50
																? 'good'
																: 'average'
													}
												>
													{summary.winrate !== null ? `${summary.winrate}%` : '—'}
												</Box>
											</Box>
										</Stack.Item>
									</Stack>
									{summary.winrate !== null && (
										<ProgressBar
											value={summary.winrate}
											minValue={0}
											maxValue={100}
											color={summary.winrate >= 50 ? 'good' : 'average'}
										>
											Винрейт: {summary.winrate}%
										</ProgressBar>
									)}
								</Section>

								{teams.length > 0 && (
									<Section
										title="Команды антагонистов"
										mb={1.5}
									>
										<Table>
											<Table.Row header>
												<Table.Cell width="180px">Команда</Table.Cell>
												<Table.Cell width="155px" textAlign="center">
													Участники
												</Table.Cell>
												<Table.Cell>Цели команды</Table.Cell>
												<Table.Cell width="105px" textAlign="center">
													Итог
												</Table.Cell>
											</Table.Row>
											{teams.map((team, idx) => {
												const membersDisplay =
													team.members_alive !== undefined
														? `${team.members_alive}/${team.members_count} живы`
														: `${team.members_count} участников`;
												return (
													<Table.Row key={`${team.name}-${idx}`}>
														<Table.Cell py={0.75} verticalAlign="middle">
															<Box bold fontSize="13px">
																{team.name}
															</Box>
															<Box color="label" fontSize="11px" mt={0.5}>
																{membersDisplay}
															</Box>
														</Table.Cell>
														<Table.Cell py={0.75} textAlign="center" verticalAlign="middle">
															<Button
																icon="users"
																compact
																color={
																	team.members_alive !== undefined &&
																	team.members_alive > 0
																		? 'good'
																		: undefined
																}
																onClick={() => act('check_teams')}
																tooltip={
																	team.members && team.members.length > 0 ? (
																		<Stack vertical g={0.5} style={{ maxWidth: '320px' }}>
																			<Box bold color="label">
																				Нажмите, чтобы открыть Check Teams:
																			</Box>
																			{team.members.map((m, mIdx) => (
																				<Box key={mIdx} fontSize="11px">
																					<Icon
																						name={m.alive ? 'heartbeat' : 'skull'}
																						color={m.alive ? 'good' : 'bad'}
																						mr={0.5}
																					/>
																					<b>{m.name}</b> ({m.ckey || m.key}) —{' '}
																					{m.alive ? 'Жив' : 'Мёртв'}
																				</Box>
																			))}
																		</Stack>
																	) : (
																		'Открыть Check Teams (нет участников)'
																	)
																}
															>
																Участники ({team.members?.length || team.members_count})
															</Button>
														</Table.Cell>
														<Table.Cell py={0.75} verticalAlign="middle">
															{team.objectives.length === 0 ? (
																<Box color="label" italic>
																	Нет общих целей команды
																</Box>
															) : (
																<Stack vertical g={0.5}>
																	{team.objectives.map((tObj, i) => (
																		<ObjectiveItem key={i} objective={tObj} />
																	))}
																</Stack>
															)}
														</Table.Cell>
														<Table.Cell py={0.75} textAlign="center" verticalAlign="middle">
															<OutcomeBadge outcome={team.outcome} />
														</Table.Cell>
													</Table.Row>
												);
											})}
										</Table>
									</Section>
								)}

								<Section
									title="Поиск и фильтры"
									mb={1.5}
									buttons={
										<Box color="label" fontSize="12px" bold nowrap>
											Показано {matchedCount} из {summary.total} антагонистов
										</Box>
									}
								>
									<Stack vertical g={1}>
										<Stack align="center" g={1}>
											<Icon name="search" color="label" />
											<Stack.Item grow>
												<Input
													fluid
													placeholder="Поиск по ckey, имени или роли..."
													value={searchQuery}
													onChange={(val) => setSearchQuery(val)}
												/>
											</Stack.Item>
											{searchQuery && (
												<Button
													icon="times"
													color="transparent"
													tooltip="Очистить поиск"
													onClick={() => setSearchQuery('')}
												/>
											)}
										</Stack>
										<Stack align="center" wrap g={0.75}>
											<Button
												selected={filterStatus === 'all'}
												onClick={() => setFilterStatus('all')}
											>
												Все
											</Button>
											<Button
												color={filterStatus === 'alive' ? 'good' : undefined}
												selected={filterStatus === 'alive'}
												icon="heartbeat"
												onClick={() => setFilterStatus('alive')}
											>
												Живые
											</Button>
											<Button
												color={filterStatus === 'dead' ? 'bad' : undefined}
												selected={filterStatus === 'dead'}
												icon="skull"
												onClick={() => setFilterStatus('dead')}
											>
												Мёртвые
											</Button>
											<Button
												selected={filterStatus === 'win'}
												icon="trophy"
												onClick={() => setFilterStatus('win')}
											>
												Победа
											</Button>
											<Button
												selected={filterStatus === 'loss'}
												icon="times-circle"
												onClick={() => setFilterStatus('loss')}
											>
												Поражение
											</Button>
											<Button
												selected={filterStatus === 'unconditional'}
												onClick={() => setFilterStatus('unconditional')}
											>
												Без условий
											</Button>
										</Stack>
									</Stack>
								</Section>

								{matchedCount === 0 ? (
									<NoticeBox info mb={1.5}>
										Нет антагонистов, удовлетворяющих заданным условиям поиска и фильтрации.
									</NoticeBox>
								) : (
									filteredCategories.map((category) => (
										<Section
											key={category.name}
											title={category.name}
											mb={1.5}
											buttons={
												<Box
													color="label"
													fontSize="11px"
													nowrap
													style={{
														maxWidth: '600px',
														overflow: 'hidden',
														textOverflow: 'ellipsis',
													}}
												>
													Показано: {category.antagonists.length} из {category.total} | Побед: {category.wins} | Поражений:{' '}
													{category.losses} | Без условий: {category.unconditional} | Винрейт:{' '}
													{category.winrate !== null ? `${category.winrate}%` : '—'}
												</Box>
											}
										>
											<Table>
												<Table.Row header>
													<Table.Cell>Игрок</Table.Cell>
													<Table.Cell>Персонаж</Table.Cell>
													<Table.Cell width="100px">Роль</Table.Cell>
													<Table.Cell width="95px">Команда</Table.Cell>
													<Table.Cell width="105px">Статус</Table.Cell>
													<Table.Cell width="100px" textAlign="center">
														Цели
													</Table.Cell>
													<Table.Cell width="95px" textAlign="center">
														Итог
													</Table.Cell>
													<Table.Cell width="190px" textAlign="center">
														Действия
													</Table.Cell>
												</Table.Row>
												{category.antagonists.map((antag) => {
													const completedCount = antag.objectives.filter(
														(o) => o.completed
													).length;
													const totalCount = antag.objectives.filter(
													(objective) => objective.completed !== null
												).length;

													return (
														<Table.Row key={antag.antag_ref}>
															<Table.Cell bold py={0.5} verticalAlign="middle">
																{antag.key}
															</Table.Cell>
															<Table.Cell py={0.5} verticalAlign="middle">
																{antag.char_name}
															</Table.Cell>
															<Table.Cell py={0.5} verticalAlign="middle">
																{antag.role}
															</Table.Cell>
															<Table.Cell py={0.5} verticalAlign="middle">
																{antag.team || (
																	<Box color="label" italic>
																		Одиночка
																	</Box>
																)}
															</Table.Cell>
															<Table.Cell py={0.5} verticalAlign="middle">
																<StatusBadge status={antag.status} />
															</Table.Cell>
															<Table.Cell py={0.5} textAlign="center" verticalAlign="middle">
																<Button
																	icon="bullseye"
																	style={{ margin: 0 }}
																	color={
																		totalCount === 0
																			? 'transparent'
																			: completedCount === totalCount
																			? 'good'
																			: completedCount > 0
																			? 'average'
																			: undefined
																	}
																	disabled={!antag.mind_ref}
																	compact
																	tooltip={
																		antag.objectives.length === 0 ? (
																			<Box italic>Нет целей</Box>
																		) : (
																			<Stack
																				vertical
																				g={0.5}
																				style={{ maxWidth: '350px' }}
																			>
																				{antag.objectives.map((obj, i) => (
																					<ObjectiveItem key={i} objective={obj} />
																				))}
																			</Stack>
																		)
																	}
																	tooltipPosition="top"
																	onClick={() =>
																		act('traitor_panel', {
																			mind_ref: antag.mind_ref,
																			mob_ref: antag.mob_ref,
																		})
																	}
																>
																	Цели{totalCount > 0 && ` (${completedCount}/${totalCount})`}
																</Button>
															</Table.Cell>
															<Table.Cell py={0.5} textAlign="center" verticalAlign="middle">
																<OutcomeBadge outcome={antag.outcome} />
															</Table.Cell>
															<Table.Cell py={0.5} textAlign="center" verticalAlign="middle">
																<Stack align="center" justify="center" g={0.5}>
																	<Button
																		icon="comment"
																		tooltip="Личное сообщение игроку"
																		disabled={!antag.ckey}
																		compact
																		onClick={() => act('pm', { ckey: antag.ckey })}
																	>
																		PM
																	</Button>
																	<Button
																		icon="eye"
																		tooltip="Следить за персонажем"
																		disabled={!antag.mob_ref}
																		compact
																		onClick={() =>
																			act('follow', { mob_ref: antag.mob_ref })
																		}
																	>
																		FLW
																	</Button>
																	<Button
																		icon="user"
																		tooltip="Панель игрока"
																		disabled={!antag.mob_ref}
																		compact
																		onClick={() =>
																			act('player_panel', {
																				mob_ref: antag.mob_ref,
																				mind_ref: antag.mind_ref,
																			})
																		}
																	>
																		PP
																	</Button>
																	{can_view_variables && (
																		<Button
																			icon="wrench"
																			tooltip="Просмотр переменных (VV)"
																			disabled={!antag.mob_ref && !antag.mind_ref}
																			compact
																			onClick={() =>
																				act('vv', {
																					target_ref:
																						antag.mob_ref || antag.mind_ref,
																				})
																			}
																		>
																			VV
																		</Button>
																	)}
																</Stack>
															</Table.Cell>
														</Table.Row>
													);
												})}
											</Table>
										</Section>
									))
								)}

								<Box />
							</>
						))}

				{activeTab === 'history' && (
					<Section
						title="История выполнения целей"
						mb={1.5}
						buttons={
							<Stack align="center" g={1.5}>
								<Stack align="center" g={0.75}>
									<Box color="label" fontSize="11px" nowrap>
										Лимит раундов
									</Box>
									{[10, 25, 50, 100].map((limit) => (
										<Button
											key={limit}
											selected={history_limit === limit}
											disabled={history_status === 'loading'}
											compact
											onClick={() => act('set_limit', { limit })}
										>
											{limit}
										</Button>
									))}
								</Stack>
								<HistoryRefreshButton
									loading={history_status === 'loading'}
									onRefresh={() => act('refresh_history')}
								/>
							</Stack>
						}
					>
						<Box color="label" mb={1}>
							Победа в этой сводке означает, что все записанные
							цели антагониста выполнены.
						</Box>
						{history_status === 'unavailable' && (
							<NoticeBox danger>База данных недоступна.</NoticeBox>
						)}
						{history_status === 'error' && (
							<NoticeBox danger>Не удалось загрузить статистику из базы данных.</NoticeBox>
						)}
						{history_status === 'loading' && (
							<NoticeBox info>Загружаем статистику из базы данных.</NoticeBox>
						)}
						{history_status === 'ready' && !history?.rounds.length && (
							<NoticeBox info>Нет сохранённых записей о целях антагонистов.</NoticeBox>
						)}
					</Section>
				)}
				{activeTab === 'history' &&
					(history && history.rounds.length > 0 ? (
							<>
								<Section title="Историческая сводка" mb={1.5}>
									<Stack g={1} mb={1.5}>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													РАУНДОВ
												</Box>
												<Box fontSize="22px" bold color="blue">
													{history.total_rounds}
												</Box>
											</Box>
										</Stack.Item>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													ВСЕГО АНТАГОНИСТОВ
												</Box>
												<Box fontSize="22px" bold color="blue">
													{history.total_antags}
												</Box>
											</Box>
										</Stack.Item>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													ПОБЕД
												</Box>
												<Box fontSize="22px" bold color="good">
													{history.total_wins}
												</Box>
											</Box>
										</Stack.Item>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													ПОРАЖЕНИЙ
												</Box>
												<Box fontSize="22px" bold color="bad">
													{history.total_losses}
												</Box>
											</Box>
										</Stack.Item>
										<Stack.Item grow>
											<Box
												p={1}
												textAlign="center"
												style={{
													backgroundColor: 'rgba(0, 0, 0, 0.2)',
													borderRadius: '4px',
												}}
											>
												<Box color="label" fontSize="11px" mb={0.5}>
													ИСТОРИЧЕСКИЙ ВИНРЕЙТ
												</Box>
												<Box
													fontSize="22px"
													bold
													color={
														history.overall_winrate === null
															? 'label'
															: history.overall_winrate >= 50
																? 'good'
																: 'average'
													}
												>
													{history.overall_winrate !== null
														? `${history.overall_winrate}%`
														: '—'}
												</Box>
											</Box>
										</Stack.Item>
									</Stack>
									{history.overall_winrate !== null && (
										<ProgressBar
											value={history.overall_winrate}
											minValue={0}
											maxValue={100}
											color={
												history.overall_winrate >= 50 ? 'good' : 'average'
											}
										>
											Общий винрейт: {history.overall_winrate}%
										</ProgressBar>
									)}
								</Section>

								{history.roles.length > 0 && (
									<Section title="Сводка по ролям за прошлые смены" mb={1.5}>
										<Table>
											<Table.Row header>
												<Table.Cell>
													<Button
														color="transparent"
														compact
														style={{ paddingLeft: 0 }}
														onClick={() => handleRoleSort('name')}
													>
														Роль антагониста{' '}
														{roleSortKey === 'name' && (
															<Icon
																name={roleSortAsc ? 'sort-up' : 'sort-down'}
															/>
														)}
													</Button>
												</Table.Cell>
												<Table.Cell width="130px">
													<Button
														color="transparent"
														compact
														style={{ paddingLeft: 0 }}
														onClick={() => handleRoleSort('total')}
													>
														Всего игроков{' '}
														{roleSortKey === 'total' && (
															<Icon
																name={roleSortAsc ? 'sort-up' : 'sort-down'}
															/>
														)}
													</Button>
												</Table.Cell>
												<Table.Cell width="100px">
													<Button
														color="transparent"
														compact
														style={{ paddingLeft: 0 }}
														onClick={() => handleRoleSort('wins')}
													>
														Побед{' '}
														{roleSortKey === 'wins' && (
															<Icon
																name={roleSortAsc ? 'sort-up' : 'sort-down'}
															/>
														)}
													</Button>
												</Table.Cell>
												<Table.Cell width="100px">
													<Button
														color="transparent"
														compact
														style={{ paddingLeft: 0 }}
														onClick={() => handleRoleSort('losses')}
													>
														Поражений{' '}
														{roleSortKey === 'losses' && (
															<Icon
																name={roleSortAsc ? 'sort-up' : 'sort-down'}
															/>
														)}
													</Button>
												</Table.Cell>
												<Table.Cell width="150px" textAlign="center">
													<Button
														color="transparent"
														compact
														onClick={() => handleRoleSort('winrate')}
													>
														Доля побед (%){' '}
														{roleSortKey === 'winrate' && (
															<Icon
																name={roleSortAsc ? 'sort-up' : 'sort-down'}
															/>
														)}
													</Button>
												</Table.Cell>
											</Table.Row>
											{sortedRoles.map((r) => (
												<Table.Row key={r.name}>
													<Table.Cell bold py={0.5} verticalAlign="middle">
														{r.name}
													</Table.Cell>
													<Table.Cell py={0.5} verticalAlign="middle">
														{r.total}
													</Table.Cell>
													<Table.Cell color="good" py={0.5} verticalAlign="middle">
														{r.wins}
													</Table.Cell>
													<Table.Cell color="bad" py={0.5} verticalAlign="middle">
														{r.losses}
													</Table.Cell>
													<Table.Cell textAlign="center" py={0.5} verticalAlign="middle">
														{r.winrate !== null ? (
															<ProgressBar
																value={r.winrate}
																minValue={0}
																maxValue={100}
																color={r.winrate >= 50 ? 'good' : 'bad'}
															>
																{r.winrate}%
															</ProgressBar>
														) : (
															<Box color="label">—</Box>
														)}
													</Table.Cell>
												</Table.Row>
											))}
										</Table>
									</Section>
								)}

								<Section title="Последние раунды" mb={1.5}>
									<Table>
										<Table.Row header>
											<Table.Cell width="140px">Номер смены</Table.Cell>
											<Table.Cell width="180px">Дата / Время</Table.Cell>
											<Table.Cell width="110px">Антагонистов</Table.Cell>
											<Table.Cell width="100px">Побед</Table.Cell>
											<Table.Cell width="100px">Поражений</Table.Cell>
											<Table.Cell width="110px" textAlign="center">
												Винрейт
											</Table.Cell>
										</Table.Row>
										{history.rounds.map((round) => (
											<Table.Row key={round.round_id}>
												<Table.Cell bold py={0.5} verticalAlign="middle">
													#{round.round_id}
												</Table.Cell>
												<Table.Cell py={0.5} verticalAlign="middle">
													{round.datetime}
												</Table.Cell>
												<Table.Cell py={0.5} verticalAlign="middle">
													{round.total}
												</Table.Cell>
												<Table.Cell color="good" py={0.5} verticalAlign="middle">
													{round.wins}
												</Table.Cell>
												<Table.Cell color="bad" py={0.5} verticalAlign="middle">
													{round.losses}
												</Table.Cell>
												<Table.Cell textAlign="center" py={0.5} verticalAlign="middle">
													<Box
														bold
														color={
															round.winrate === null
																? 'label'
																: round.winrate >= 50
																	? 'good'
																	: 'bad'
														}
													>
														{round.winrate !== null
															? `${round.winrate}%`
															: '—'}
													</Box>
												</Table.Cell>
											</Table.Row>
										))}
									</Table>
								</Section>
							</>
						) : null)}
			</Window.Content>
		</Window>
	);
}
