package com.investimentos.personalProject.auth.dto;

public record RegisterRequest(
        String name,
        String email,
        String password
) {
}
