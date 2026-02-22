import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  static String getMessage(dynamic error) {
    // -------------------------------------------------------
    // NETWORK / OFFLINE
    // -------------------------------------------------------
    if (error is SocketException) {
      return "No internet connection. Please check your network and try again.";
    }

    // -------------------------------------------------------
    // AUTH ERRORS
    // -------------------------------------------------------
    if (error is AuthException) {
      final msg = error.message.toLowerCase();

      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid email or password')) {
        return "Invalid email or password. Please try again.";
      }

      if (msg.contains('email not confirmed')) {
        return "Please confirm your email before signing in.";
      }

      if (msg.contains('user already registered')) {
        return "An account with this email already exists.";
      }

      return error.message;
    }

    // -------------------------------------------------------
    // DATABASE / RLS / POSTGRES ERRORS
    // -------------------------------------------------------
    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();

      if (msg.contains('row-level security')) {
        return "You are not allowed to perform this action.";
      }

      if (msg.contains('duplicate key')) {
        return "This record already exists.";
      }

      if (msg.contains('foreign key')) {
        return "This item is linked to other data and cannot be changed.";
      }

      return "A database error occurred. Please try again.";
    }

    // -------------------------------------------------------
    // TIMEOUTS / SERVER UNREACHABLE
    // -------------------------------------------------------
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('timeout')) {
      return "Connection timed out. Please try again later.";
    }

    if (errorStr.contains('failed host lookup') ||
        errorStr.contains('connection refused')) {
      return "Unable to connect to the server. Please check your internet connection.";
    }

    if (errorStr.contains('404')) {
      return "Service not found. Please contact support.";
    }

    // -------------------------------------------------------
    // FALLBACK (SAFE)
    // -------------------------------------------------------
    return "Something went wrong. Please try again.";
  }
}