package com.investimentos.personalProject.auth.controller;

import com.investimentos.personalProject.auth.dto.LoginRequest;
import com.investimentos.personalProject.auth.dto.LoginResponse;
import com.investimentos.personalProject.auth.dto.RegisterRequest;
import com.investimentos.personalProject.auth.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService){
        this.authService = authService;
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@RequestBody @Valid LoginRequest loginRequest){

        LoginResponse loginResponse = authService.login(loginRequest);

        return ResponseEntity.ok(loginResponse);
    }

    @PostMapping("/register")
    public ResponseEntity<Void> register(@RequestBody @Valid RegisterRequest registerRequest){

        authService.register(registerRequest);
        return ResponseEntity.ok().build();
    }
}
