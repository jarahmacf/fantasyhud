export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      fantasy_account_leagues: {
        Row: {
          created_at: string
          fantasy_account_id: string
          first_seen_at: string
          id: string
          last_seen_at: string
          league_id: string
          removed_at: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          fantasy_account_id: string
          first_seen_at: string
          id?: string
          last_seen_at: string
          league_id: string
          removed_at?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          fantasy_account_id?: string
          first_seen_at?: string
          id?: string
          last_seen_at?: string
          league_id?: string
          removed_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fantasy_account_leagues_fantasy_account_id_fkey"
            columns: ["fantasy_account_id"]
            isOneToOne: false
            referencedRelation: "fantasy_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fantasy_account_leagues_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
            referencedColumns: ["id"]
          },
        ]
      }
      fantasy_account_rosters: {
        Row: {
          created_at: string
          fantasy_account_id: string
          first_seen_at: string
          id: string
          last_seen_at: string
          league_id: string
          ownership_role: string
          removed_at: string | null
          roster_id: string
          source_metadata: Json
          updated_at: string
        }
        Insert: {
          created_at?: string
          fantasy_account_id: string
          first_seen_at: string
          id?: string
          last_seen_at: string
          league_id: string
          ownership_role: string
          removed_at?: string | null
          roster_id: string
          source_metadata?: Json
          updated_at?: string
        }
        Update: {
          created_at?: string
          fantasy_account_id?: string
          first_seen_at?: string
          id?: string
          last_seen_at?: string
          league_id?: string
          ownership_role?: string
          removed_at?: string | null
          roster_id?: string
          source_metadata?: Json
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fantasy_account_rosters_account_league_fkey"
            columns: ["fantasy_account_id", "league_id"]
            isOneToOne: false
            referencedRelation: "fantasy_account_leagues"
            referencedColumns: ["fantasy_account_id", "league_id"]
          },
          {
            foreignKeyName: "fantasy_account_rosters_roster_league_fkey"
            columns: ["roster_id", "league_id"]
            isOneToOne: false
            referencedRelation: "rosters"
            referencedColumns: ["id", "league_id"]
          },
        ]
      }
      fantasy_accounts: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string | null
          external_user_id: string
          id: string
          last_synced_at: string | null
          normalized_username: string
          provider: string
          provider_metadata: Json
          provider_updated_at: string | null
          updated_at: string
          username: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          external_user_id: string
          id?: string
          last_synced_at?: string | null
          normalized_username: string
          provider: string
          provider_metadata?: Json
          provider_updated_at?: string | null
          updated_at?: string
          username: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          external_user_id?: string
          id?: string
          last_synced_at?: string | null
          normalized_username?: string
          provider?: string
          provider_metadata?: Json
          provider_updated_at?: string | null
          updated_at?: string
          username?: string
        }
        Relationships: []
      }
      league_users: {
        Row: {
          avatar_id: string | null
          avatar_url: string | null
          created_at: string
          display_name: string | null
          external_user_id: string
          fetched_at: string
          first_seen_at: string
          id: string
          is_commissioner: boolean
          last_seen_at: string
          league_id: string
          metadata: Json
          removed_at: string | null
          team_name: string | null
          updated_at: string
          username: string | null
        }
        Insert: {
          avatar_id?: string | null
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          external_user_id: string
          fetched_at: string
          first_seen_at: string
          id?: string
          is_commissioner?: boolean
          last_seen_at: string
          league_id: string
          metadata?: Json
          removed_at?: string | null
          team_name?: string | null
          updated_at?: string
          username?: string | null
        }
        Update: {
          avatar_id?: string | null
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          external_user_id?: string
          fetched_at?: string
          first_seen_at?: string
          id?: string
          is_commissioner?: boolean
          last_seen_at?: string
          league_id?: string
          metadata?: Json
          removed_at?: string | null
          team_name?: string | null
          updated_at?: string
          username?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "league_users_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
            referencedColumns: ["id"]
          },
        ]
      }
      leagues: {
        Row: {
          avatar_id: string | null
          avatar_url: string | null
          created_at: string
          external_league_id: string
          fetched_at: string
          has_idp: boolean
          has_superflex: boolean
          id: string
          is_best_ball: boolean
          name: string
          previous_external_league_id: string | null
          provider: string
          provider_metadata: Json
          provider_updated_at: string | null
          roster_management_type: string
          roster_positions: Json
          roster_size: number
          scoring_format: string
          scoring_settings: Json
          season: number
          season_type: string
          settings: Json
          sport: string
          status: string
          team_count: number
          updated_at: string
        }
        Insert: {
          avatar_id?: string | null
          avatar_url?: string | null
          created_at?: string
          external_league_id: string
          fetched_at: string
          has_idp: boolean
          has_superflex: boolean
          id?: string
          is_best_ball: boolean
          name: string
          previous_external_league_id?: string | null
          provider: string
          provider_metadata?: Json
          provider_updated_at?: string | null
          roster_management_type: string
          roster_positions: Json
          roster_size: number
          scoring_format: string
          scoring_settings: Json
          season: number
          season_type: string
          settings: Json
          sport: string
          status: string
          team_count: number
          updated_at?: string
        }
        Update: {
          avatar_id?: string | null
          avatar_url?: string | null
          created_at?: string
          external_league_id?: string
          fetched_at?: string
          has_idp?: boolean
          has_superflex?: boolean
          id?: string
          is_best_ball?: boolean
          name?: string
          previous_external_league_id?: string | null
          provider?: string
          provider_metadata?: Json
          provider_updated_at?: string | null
          roster_management_type?: string
          roster_positions?: Json
          roster_size?: number
          scoring_format?: string
          scoring_settings?: Json
          season?: number
          season_type?: string
          settings?: Json
          sport?: string
          status?: string
          team_count?: number
          updated_at?: string
        }
        Relationships: []
      }
      player_external_ids: {
        Row: {
          created_at: string
          external_id: string
          first_seen_at: string
          id: string
          is_primary: boolean
          last_seen_at: string
          namespace: string
          player_id: string
          removed_at: string | null
          reported_by: string
          source_metadata: Json
          sport: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          external_id: string
          first_seen_at: string
          id?: string
          is_primary?: boolean
          last_seen_at: string
          namespace: string
          player_id: string
          removed_at?: string | null
          reported_by: string
          source_metadata?: Json
          sport: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          external_id?: string
          first_seen_at?: string
          id?: string
          is_primary?: boolean
          last_seen_at?: string
          namespace?: string
          player_id?: string
          removed_at?: string | null
          reported_by?: string
          source_metadata?: Json
          sport?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "player_external_ids_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
        ]
      }
      players: {
        Row: {
          active: boolean | null
          age: number | null
          birth_country: string | null
          college: string | null
          created_at: string
          depth_chart_order: number | null
          depth_chart_position: number | null
          display_name: string | null
          entity_type: string
          fantasy_positions: string[]
          first_name: string | null
          full_name: string | null
          height: string | null
          high_school: string | null
          id: string
          injury_body_part: string | null
          injury_start_date: string | null
          injury_status: string | null
          jersey_number: number | null
          last_name: string | null
          news_updated_at: string | null
          nfl_team: string | null
          practice_participation: string | null
          primary_position: string | null
          profile_fetched_at: string
          profile_source: string
          search_rank: number | null
          source_metadata: Json
          sport: string
          status: string | null
          updated_at: string
          weight: string | null
          years_experience: number | null
        }
        Insert: {
          active?: boolean | null
          age?: number | null
          birth_country?: string | null
          college?: string | null
          created_at?: string
          depth_chart_order?: number | null
          depth_chart_position?: number | null
          display_name?: string | null
          entity_type: string
          fantasy_positions?: string[]
          first_name?: string | null
          full_name?: string | null
          height?: string | null
          high_school?: string | null
          id?: string
          injury_body_part?: string | null
          injury_start_date?: string | null
          injury_status?: string | null
          jersey_number?: number | null
          last_name?: string | null
          news_updated_at?: string | null
          nfl_team?: string | null
          practice_participation?: string | null
          primary_position?: string | null
          profile_fetched_at: string
          profile_source: string
          search_rank?: number | null
          source_metadata?: Json
          sport: string
          status?: string | null
          updated_at?: string
          weight?: string | null
          years_experience?: number | null
        }
        Update: {
          active?: boolean | null
          age?: number | null
          birth_country?: string | null
          college?: string | null
          created_at?: string
          depth_chart_order?: number | null
          depth_chart_position?: number | null
          display_name?: string | null
          entity_type?: string
          fantasy_positions?: string[]
          first_name?: string | null
          full_name?: string | null
          height?: string | null
          high_school?: string | null
          id?: string
          injury_body_part?: string | null
          injury_start_date?: string | null
          injury_status?: string | null
          jersey_number?: number | null
          last_name?: string | null
          news_updated_at?: string | null
          nfl_team?: string | null
          practice_participation?: string | null
          primary_position?: string | null
          profile_fetched_at?: string
          profile_source?: string
          search_rank?: number | null
          source_metadata?: Json
          sport?: string
          status?: string | null
          updated_at?: string
          weight?: string | null
          years_experience?: number | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string | null
          id: string
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      provider_catalog_runs: {
        Row: {
          catalog: string
          created_at: string
          error_summary: Json
          finished_at: string | null
          id: string
          progress_current: number
          progress_total: number
          provider: string
          result_counts: Json
          source_bytes: number | null
          source_fetched_at: string | null
          source_record_count: number | null
          sport: string
          started_at: string
          status: string
          triggered_by_user_id: string | null
          updated_at: string
        }
        Insert: {
          catalog: string
          created_at?: string
          error_summary?: Json
          finished_at?: string | null
          id?: string
          progress_current?: number
          progress_total?: number
          provider: string
          result_counts?: Json
          source_bytes?: number | null
          source_fetched_at?: string | null
          source_record_count?: number | null
          sport: string
          started_at: string
          status: string
          triggered_by_user_id?: string | null
          updated_at?: string
        }
        Update: {
          catalog?: string
          created_at?: string
          error_summary?: Json
          finished_at?: string | null
          id?: string
          progress_current?: number
          progress_total?: number
          provider?: string
          result_counts?: Json
          source_bytes?: number | null
          source_fetched_at?: string | null
          source_record_count?: number | null
          sport?: string
          started_at?: string
          status?: string
          triggered_by_user_id?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      provider_season_states: {
        Row: {
          created_at: string
          display_week: number | null
          fetched_at: string
          id: string
          league_create_season: number | null
          league_season: number
          leg: number | null
          previous_season: number | null
          provider: string
          provider_metadata: Json
          season: number
          season_start_date: string | null
          season_type: string
          sport: string
          updated_at: string
          week: number | null
        }
        Insert: {
          created_at?: string
          display_week?: number | null
          fetched_at: string
          id?: string
          league_create_season?: number | null
          league_season: number
          leg?: number | null
          previous_season?: number | null
          provider: string
          provider_metadata?: Json
          season: number
          season_start_date?: string | null
          season_type: string
          sport: string
          updated_at?: string
          week?: number | null
        }
        Update: {
          created_at?: string
          display_week?: number | null
          fetched_at?: string
          id?: string
          league_create_season?: number | null
          league_season?: number
          leg?: number | null
          previous_season?: number | null
          provider?: string
          provider_metadata?: Json
          season?: number
          season_start_date?: string | null
          season_type?: string
          sport?: string
          updated_at?: string
          week?: number | null
        }
        Relationships: []
      }
      roster_players: {
        Row: {
          created_at: string
          first_seen_at: string
          id: string
          is_keeper: boolean
          is_reserve: boolean
          is_starter: boolean
          is_taxi: boolean
          last_seen_at: string
          league_id: string
          player_id: string
          removed_at: string | null
          roster_id: string
          source_metadata: Json
          source_order: number | null
          source_player_external_id_id: string
          starter_order: number | null
          starter_slot: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          first_seen_at: string
          id?: string
          is_keeper?: boolean
          is_reserve?: boolean
          is_starter?: boolean
          is_taxi?: boolean
          last_seen_at: string
          league_id: string
          player_id: string
          removed_at?: string | null
          roster_id: string
          source_metadata?: Json
          source_order?: number | null
          source_player_external_id_id: string
          starter_order?: number | null
          starter_slot?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          first_seen_at?: string
          id?: string
          is_keeper?: boolean
          is_reserve?: boolean
          is_starter?: boolean
          is_taxi?: boolean
          last_seen_at?: string
          league_id?: string
          player_id?: string
          removed_at?: string | null
          roster_id?: string
          source_metadata?: Json
          source_order?: number | null
          source_player_external_id_id?: string
          starter_order?: number | null
          starter_slot?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "roster_players_mapping_player_fkey"
            columns: ["source_player_external_id_id", "player_id"]
            isOneToOne: false
            referencedRelation: "player_external_ids"
            referencedColumns: ["id", "player_id"]
          },
          {
            foreignKeyName: "roster_players_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "roster_players_roster_league_fkey"
            columns: ["roster_id", "league_id"]
            isOneToOne: false
            referencedRelation: "rosters"
            referencedColumns: ["id", "league_id"]
          },
        ]
      }
      rosters: {
        Row: {
          co_owner_external_user_ids: string[] | null
          created_at: string
          external_roster_id: number
          fetched_at: string
          first_seen_at: string
          id: string
          last_seen_at: string
          league_id: string
          metadata: Json
          owner_external_user_id: string | null
          removed_at: string | null
          settings: Json
          source_keeper_ids: string[] | null
          source_player_ids: string[] | null
          source_reserve_ids: string[] | null
          source_starter_ids: string[] | null
          source_taxi_ids: string[] | null
          updated_at: string
        }
        Insert: {
          co_owner_external_user_ids?: string[] | null
          created_at?: string
          external_roster_id: number
          fetched_at: string
          first_seen_at: string
          id?: string
          last_seen_at: string
          league_id: string
          metadata?: Json
          owner_external_user_id?: string | null
          removed_at?: string | null
          settings?: Json
          source_keeper_ids?: string[] | null
          source_player_ids?: string[] | null
          source_reserve_ids?: string[] | null
          source_starter_ids?: string[] | null
          source_taxi_ids?: string[] | null
          updated_at?: string
        }
        Update: {
          co_owner_external_user_ids?: string[] | null
          created_at?: string
          external_roster_id?: number
          fetched_at?: string
          first_seen_at?: string
          id?: string
          last_seen_at?: string
          league_id?: string
          metadata?: Json
          owner_external_user_id?: string | null
          removed_at?: string | null
          settings?: Json
          source_keeper_ids?: string[] | null
          source_player_ids?: string[] | null
          source_reserve_ids?: string[] | null
          source_starter_ids?: string[] | null
          source_taxi_ids?: string[] | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rosters_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "leagues"
            referencedColumns: ["id"]
          },
        ]
      }
      sync_runs: {
        Row: {
          created_at: string
          error_summary: Json
          fantasy_account_id: string
          finished_at: string | null
          id: string
          progress_current: number
          progress_total: number
          provider: string
          result_counts: Json
          scope: string
          season: number | null
          sport: string
          started_at: string
          status: string
          triggered_by_user_id: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          error_summary?: Json
          fantasy_account_id: string
          finished_at?: string | null
          id?: string
          progress_current?: number
          progress_total?: number
          provider: string
          result_counts?: Json
          scope: string
          season?: number | null
          sport: string
          started_at: string
          status: string
          triggered_by_user_id?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          error_summary?: Json
          fantasy_account_id?: string
          finished_at?: string | null
          id?: string
          progress_current?: number
          progress_total?: number
          provider?: string
          result_counts?: Json
          scope?: string
          season?: number | null
          sport?: string
          started_at?: string
          status?: string
          triggered_by_user_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "sync_runs_fantasy_account_id_fkey"
            columns: ["fantasy_account_id"]
            isOneToOne: false
            referencedRelation: "fantasy_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      user_fantasy_accounts: {
        Row: {
          created_at: string
          fantasy_account_id: string
          id: string
          is_primary: boolean
          label: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          fantasy_account_id: string
          id?: string
          is_primary?: boolean
          label?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          fantasy_account_id?: string
          id?: string
          is_primary?: boolean
          label?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_fantasy_accounts_fantasy_account_id_fkey"
            columns: ["fantasy_account_id"]
            isOneToOne: false
            referencedRelation: "fantasy_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      complete_sleeper_league_discovery: {
        Args: {
          p_fantasy_account_id: string
          p_leagues: Json
          p_state: Json
          p_sync_run_id: string
          p_user_id: string
        }
        Returns: {
          active_associations: number
          created_associations: number
          created_leagues: number
          observed_leagues: number
          provider_state_applied: boolean
          provider_state_stale_skipped: boolean
          reactivated_associations: number
          removed_associations: number
          stale_shared_leagues_skipped: number
          sync_run_id: string
          updated_leagues: number
        }[]
      }
      complete_sleeper_player_catalog_sync: {
        Args: { p_catalog_run_id: string; p_user_id: string }
        Returns: {
          active_players: number
          ambiguous_secondary_ids_skipped: number
          catalog_run_id: string
          conflicting_secondary_ids_skipped: number
          created_players: number
          created_sleeper_ids: number
          normalization_warning_count: number
          observed_records: number
          reactivated_sleeper_ids: number
          records_with_warnings: number
          removed_sleeper_ids: number
          secondary_ids_created: number
          secondary_ids_refreshed: number
          secondary_ids_replaced: number
          stale_player_profiles_skipped: number
          team_defenses: number
          unknown_entities: number
          updated_players: number
        }[]
      }
      connect_sleeper_account: {
        Args: {
          p_avatar_url: string
          p_display_name: string
          p_external_user_id: string
          p_provider_metadata: Json
          p_user_id: string
          p_username: string
        }
        Returns: {
          created_link: boolean
          fantasy_account_id: string
          is_primary: boolean
          user_fantasy_account_id: string
        }[]
      }
      fail_sleeper_league_discovery: {
        Args: {
          p_error_code: string
          p_error_message: string
          p_fantasy_account_id: string
          p_retryable: boolean
          p_sync_run_id: string
          p_user_id: string
        }
        Returns: {
          changed_run: boolean
          status: string
          sync_run_id: string
        }[]
      }
      fail_sleeper_player_catalog_sync: {
        Args: {
          p_catalog_run_id: string
          p_error_code: string
          p_error_message: string
          p_retryable: boolean
          p_user_id: string
        }
        Returns: {
          catalog_run_id: string
          changed_run: boolean
          status: string
        }[]
      }
      stage_sleeper_player_catalog_batch: {
        Args: {
          p_batch_index: number
          p_catalog_run_id: string
          p_expected_total: number
          p_records: Json
          p_source_bytes: number
          p_source_fetched_at: string
          p_user_id: string
        }
        Returns: {
          catalog_run_id: string
          progress_total: number
          replayed_batch: boolean
          staged_records: number
          total_staged_records: number
        }[]
      }
      start_sleeper_league_discovery: {
        Args: { p_fantasy_account_id: string; p_user_id: string }
        Returns: {
          created_run: boolean
          recovered_stale_run: boolean
          reused_run: boolean
          sync_run_id: string
        }[]
      }
      start_sleeper_player_catalog_sync: {
        Args: { p_user_id: string }
        Returns: {
          catalog_fresh: boolean
          catalog_run_id: string
          created_run: boolean
          last_success_at: string
          recovered_stale_run: boolean
          reused_run: boolean
        }[]
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema["Enums"] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
