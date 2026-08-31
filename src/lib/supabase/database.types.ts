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
      start_sleeper_league_discovery: {
        Args: { p_fantasy_account_id: string; p_user_id: string }
        Returns: {
          created_run: boolean
          recovered_stale_run: boolean
          reused_run: boolean
          sync_run_id: string
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
