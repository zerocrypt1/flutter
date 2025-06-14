const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcryptjs'); // Using bcryptjs consistently across codebase
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const { OAuth2Client } = require('google-auth-library');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5050;

// Initialize Google OAuth client
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const client = new OAuth2Client(GOOGLE_CLIENT_ID);

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  family: 4,
})
  .then(() => console.log('✅ MongoDB connected'))
  .catch(err => {
    console.error('❌ MongoDB connection error:', err);
    process.exit(1);
  });

// Models
const User = mongoose.model('user', new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  googleId: { type: String }, // For Google authentication
  address: { type: String, required: false }, // Made non-required for Google users
  phone: { type: String, required: false, unique: true }, // Made non-required for Google users
  password: { type: String, required: false }, // Made non-required for Google users
  isVerified: { type: Boolean, default: false }, // Added for OTP verification
  location: {
    latitude: { type: Number },
    longitude: { type: Number },
  },
  favorites: [{ type: mongoose.Schema.Types.ObjectId, ref: 'formdatas' }],
}));

const FormData = mongoose.model('formdatas', new mongoose.Schema({
  name: { type: String, required: true },
  occupation: { type: String, required: true },
  phoneNumber: { type: String, required: true },
  identityProof: String,
  landmarks: String,
  age: { type: Number, required: true },
  state: String,
  address: String,
  otpCode: String,
  timing: { type: String }, // e.g., "Morning", "Evening"
  altPhoneNumber: String,
  idProofNumber: String,
  blueTicket: Boolean,
  pinCode: String,
  city: String,
  gender: String,
  location: {
    latitude: { type: Number },
    longitude: { type: Number },
  },
}));

// In-memory OTP storage (for demonstration - use Redis or a database in production)
const otpStore = new Map();

// Configure nodemailer
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD
  }
});

// Helper to generate OTP
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Auth middleware
const auth = async (req, res, next) => {
  try {
    // Get token from header
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ msg: 'No token, authorization denied' });
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Add user from payload
    req.user = { id: decoded.id || decoded.user.id }; // Handle both token formats
    next();
  } catch (error) {
    res.status(401).json({ msg: 'Token is not valid' });
  }
};

// 🧾 AUTH ROUTES

// Sign up with OTP verification
app.post('/api/auth/signup', async (req, res) => {
  try {
    const { name, email, address, phone, password } = req.body;

    // Check if user already exists
    let user = await User.findOne({ email });
    if (user) {
      return res.status(400).json({ msg: 'User already exists with this email' });
    }

    if (phone) {
      user = await User.findOne({ phone });
      if (user) {
        return res.status(400).json({ msg: 'Phone number already registered' });
      }
    }

    // Generate OTP
    const otp = generateOTP();
    
    // Generate temporary token for OTP verification
    const tempToken = crypto.randomBytes(20).toString('hex');
    
    // Store OTP and user info temporarily
    otpStore.set(tempToken, {
      name,
      email,
      phone,
      address,
      password, // Will be hashed before storing in the database
      otp,
      createdAt: Date.now() // For OTP expiration
    });
    
    // Send OTP via email
    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Email Verification OTP',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 5px;">
          <h2 style="color: #673ab7;">Verify Your Email</h2>
          <p>Thank you for signing up! Please use the following verification code to complete your registration:</p>
          <div style="background-color: #f2f2f2; padding: 10px; text-align: center; font-size: 24px; letter-spacing: 5px; margin: 20px 0; border-radius: 5px;">
            <strong>${otp}</strong>
          </div>
          <p>This code will expire in 10 minutes.</p>
          <p>If you didn't request this verification, please ignore this email.</p>
        </div>
      `
    });

    // Return success with temporary token
    res.status(201).json({ 
      msg: 'OTP sent to your email for verification',
      tempToken 
    });
    
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// Verify OTP endpoint
app.post('/api/auth/verify-otp', async (req, res) => {
  try {
    const { email, otp, tempToken } = req.body;
    
    // Get stored data
    const userData = otpStore.get(tempToken);
    
    if (!userData) {
      return res.status(400).json({ msg: 'Invalid or expired verification session' });
    }
    
    // Check if OTP is valid and not expired (10 minutes)
    const isExpired = Date.now() - userData.createdAt > 10 * 60 * 1000;
    
    if (isExpired) {
      otpStore.delete(tempToken);
      return res.status(400).json({ msg: 'OTP has expired. Please request a new one' });
    }
    
    if (userData.otp !== otp || userData.email !== email) {
      return res.status(400).json({ msg: 'Invalid OTP' });
    }
    
    // Hash password before storing
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(userData.password, salt);
    
    // Create new user
    const user = new User({
      name: userData.name,
      email: userData.email,
      phone: userData.phone,
      address: userData.address,
      password: hashedPassword,
      isVerified: true,
      favorites: []
    });
    
    await user.save();
    
    // Remove temp data
    otpStore.delete(tempToken);
    
    // Generate JWT
    const token = jwt.sign(
      { id: user._id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );
    
    res.json({ token, userId: user._id });
    
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// Resend OTP endpoint
app.post('/api/auth/resend-otp', async (req, res) => {
  try {
    const { email, tempToken } = req.body;
    
    // Check if user data exists
    const userData = otpStore.get(tempToken);
    if (!userData || userData.email !== email) {
      return res.status(400).json({ msg: 'Invalid session' });
    }
    
    // Generate new OTP
    const newOTP = generateOTP();
    
    // Update OTP and timestamp
    userData.otp = newOTP;
    userData.createdAt = Date.now();
    otpStore.set(tempToken, userData);
    
    // Send new OTP via email
    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Email Verification OTP (Resent)',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 5px;">
          <h2 style="color: #673ab7;">Verify Your Email</h2>
          <p>Here is your new verification code:</p>
          <div style="background-color: #f2f2f2; padding: 10px; text-align: center; font-size: 24px; letter-spacing: 5px; margin: 20px 0; border-radius: 5px;">
            <strong>${newOTP}</strong>
          </div>
          <p>This code will expire in 10 minutes.</p>
          <p>If you didn't request this verification, please ignore this email.</p>
        </div>
      `
    });
    
    res.status(200).json({ msg: 'OTP resent successfully' });
    
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// Sign in with phone/password
app.post('/api/auth/signin', async (req, res) => {
  const { phone, password } = req.body;

  try {
    const user = await User.findOne({ phone });
    if (!user) return res.status(400).json({ msg: 'Invalid credentials' });

    // Check if user is verified
    if (!user.isVerified) {
      return res.status(401).json({ msg: 'Please verify your account first' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ msg: 'Invalid credentials' });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    res.json({ token, userId: user._id });
  } catch (error) {
    console.error(error);
    res.status(500).json({ msg: 'Server error' });
  }
});

// Sign in with email (alternative)
app.post('/api/auth/signin-email', async (req, res) => {
  const { email, password } = req.body;

  try {
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ msg: 'Invalid credentials' });

    // Check if user is verified
    if (!user.isVerified) {
      return res.status(401).json({ msg: 'Please verify your account first' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ msg: 'Invalid credentials' });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    res.json({ token, userId: user._id });
  } catch (error) {
    console.error(error);
    res.status(500).json({ msg: 'Server error' });
  }
});

// 🔍 GOOGLE AUTHENTICATION ROUTE
app.post('/api/auth/google', async (req, res) => {
  try {
    const { idToken, name, email } = req.body;
    
    // Verify the Google ID token
    const ticket = await client.verifyIdToken({
      idToken: idToken,
      audience: GOOGLE_CLIENT_ID,
    });
    
    const payload = ticket.getPayload();
    const googleId = payload['sub']; // Google's unique identifier for the user
    
    let user = await User.findOne({ googleId });
    
    if (!user && email) {
      user = await User.findOne({ email });
      
      if (user && !user.googleId) {
        user.googleId = googleId;
        await user.save();
      }
    }
    
    if (!user) {
      const randomPassword = Math.random().toString(36).slice(-8) + Math.random().toString(36).slice(-8);
      
      user = new User({
        name: name || payload.name,
        email: email || payload.email,
        googleId: googleId,
        address: '',
        phone: '',
        password: await bcrypt.hash(randomPassword, 10),
        isVerified: true, // Google-authenticated users are pre-verified
        favorites: []
      });
      
      await user.save();
    }
    
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
    
    res.status(200).json({
      token,
      userId: user._id,
      name: user.name,
      email: user.email
    });
    
  } catch (error) {
    console.error('Google authentication error:', error);
    res.status(500).json({ msg: 'Server error during Google authentication' });
  }
});

// 👤 USER ROUTES
app.get('/api/users/:id', auth, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).populate('favorites');
    if (!user) return res.status(404).json({ message: 'User not found' });
    
    // Remove sensitive information
    const userResponse = {
      _id: user._id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      address: user.address,
      location: user.location,
      isVerified: user.isVerified,
      favorites: user.favorites
    };
    
    res.status(200).json(userResponse);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error fetching user', error });
  }
});

app.put('/api/users/:id', auth, async (req, res) => {
  try {
    // Ensure the authenticated user is the same as the one being updated
    if (req.user.id !== req.params.id) {
      return res.status(403).json({ message: 'Not authorized to update this user' });
    }

    // Don't allow updating sensitive fields directly
    const { password, isVerified, googleId, ...updateData } = req.body;
    
    const updatedUser = await User.findByIdAndUpdate(
      req.params.id, 
      updateData, 
      { new: true }
    );
    
    if (!updatedUser) return res.status(404).json({ message: 'User not found' });
    
    // Return user without sensitive information
    const userResponse = {
      _id: updatedUser._id,
      name: updatedUser.name,
      email: updatedUser.email,
      phone: updatedUser.phone,
      address: updatedUser.address,
      location: updatedUser.location,
      isVerified: updatedUser.isVerified,
      favorites: updatedUser.favorites
    };
    
    res.status(200).json(userResponse);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error updating user', error });
  }
});

// Update user location
app.put('/api/users/:id/location', auth, async (req, res) => {
  const { latitude, longitude } = req.body;

  try {
    // Ensure the authenticated user is the same as the one being updated
    if (req.user.id !== req.params.id) {
      return res.status(403).json({ message: 'Not authorized to update this user' });
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      { location: { latitude, longitude } },
      { new: true }
    );
    
    if (!updatedUser) return res.status(404).json({ message: 'User not found' });
    
    res.status(200).json({
      message: 'Location updated successfully',
      location: updatedUser.location
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error updating location', error });
  }
});

// Change password (requires old password verification)
app.put('/api/users/:id/password', auth, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  
  try {
    // Ensure the authenticated user is the same as the one being updated
    if (req.user.id !== req.params.id) {
      return res.status(403).json({ message: 'Not authorized to update this user' });
    }
    
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: 'User not found' });
    
    // For users with password (non-Google accounts)
    if (user.password) {
      const isMatch = await bcrypt.compare(currentPassword, user.password);
      if (!isMatch) return res.status(400).json({ message: 'Current password is incorrect' });
    }
    
    // Hash and update the password
    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    
    await user.save();
    
    res.status(200).json({ message: 'Password updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error updating password', error });
  }
});

// ❤️ FAVORITES ROUTES
app.post('/api/users/:userId/favorites', auth, async (req, res) => {
  const { applicantId } = req.body;

  try {
    // Ensure the authenticated user is the same as the one being updated
    if (req.user.id !== req.params.userId) {
      return res.status(403).json({ message: 'Not authorized to update favorites' });
    }

    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ msg: 'User not found' });

    // Check if the applicant exists
    const applicant = await FormData.findById(applicantId);
    if (!applicant) return res.status(404).json({ msg: 'Applicant not found' });

    // Check if already in favorites
    if (!user.favorites.includes(applicantId)) {
      user.favorites.push(applicantId);
      await user.save();
    }

    res.status(200).json({ msg: 'Favorite added successfully', favorites: user.favorites });
  } catch (error) {
    console.error('Error adding favorite:', error);
    res.status(500).json({ msg: 'Failed to add favorite' });
  }
});

app.delete('/api/users/:userId/favorites/:applicantId', auth, async (req, res) => {
  try {
    // Ensure the authenticated user is the same as the one being updated
    if (req.user.id !== req.params.userId) {
      return res.status(403).json({ message: 'Not authorized to update favorites' });
    }

    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ msg: 'User not found' });

    // Check if the applicant exists in the favorites
    const index = user.favorites.indexOf(req.params.applicantId);
    if (index === -1) return res.status(404).json({ msg: 'Applicant not found in favorites' });

    // Remove from favorites
    user.favorites.splice(index, 1);
    await user.save();

    res.status(200).json({ msg: 'Favorite removed successfully', favorites: user.favorites });
  } catch (error) {
    console.error('Error removing favorite:', error);
    res.status(500).json({ msg: 'Failed to remove favorite' });
  }
});

// Get user favorites
app.get('/api/users/:userId/favorites', auth, async (req, res) => {
  try {
    // Ensure the authenticated user is the same as the one being queried
    if (req.user.id !== req.params.userId) {
      return res.status(403).json({ message: 'Not authorized to view these favorites' });
    }

    const user = await User.findById(req.params.userId).populate('favorites');
    if (!user) return res.status(404).json({ msg: 'User not found' });

    res.status(200).json({ favorites: user.favorites });
  } catch (error) {
    console.error('Error fetching favorites:', error);
    res.status(500).json({ msg: 'Failed to fetch favorites' });
  }
});

// 📋 FORM DATA ROUTES
app.get('/api/formdatas', async (req, res) => {
  try {
    const data = await FormData.find();
    res.status(200).json(data);
  } catch (error) {
    console.error('Error fetching applicants data:', error);
    res.status(500).json({ msg: 'Failed to load applicants data' });
  }
});

app.get('/api/formdatas/:id', async (req, res) => {
  try {
    const applicant = await FormData.findById(req.params.id);
    if (!applicant) return res.status(404).json({ msg: 'Applicant not found' });
    res.status(200).json(applicant);
  } catch (error) {
    console.error('Error fetching applicant:', error);
    res.status(500).json({ msg: 'Server error' });
  }
});

// Add new FormData (protected by auth)
app.post('/api/formdatas', auth, async (req, res) => {
  try {
    const newFormData = new FormData(req.body);
    const savedData = await newFormData.save();
    res.status(201).json(savedData);
  } catch (error) {
    console.error('Error creating form data:', error);
    res.status(500).json({ msg: 'Failed to create form data' });
  }
});

// Update FormData (protected by auth)
app.put('/api/formdatas/:id', auth, async (req, res) => {
  try {
    const updatedData = await FormData.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    
    if (!updatedData) return res.status(404).json({ msg: 'Form data not found' });
    
    res.status(200).json(updatedData);
  } catch (error) {
    console.error('Error updating form data:', error);
    res.status(500).json({ msg: 'Failed to update form data' });
  }
});

// Delete FormData (protected by auth, could add admin-only check)
app.delete('/api/formdatas/:id', auth, async (req, res) => {
  try {
    const deletedData = await FormData.findByIdAndDelete(req.params.id);
    
    if (!deletedData) return res.status(404).json({ msg: 'Form data not found' });
    
    // Also remove this form data from all users' favorites
    await User.updateMany(
      { favorites: req.params.id },
      { $pull: { favorites: req.params.id } }
    );
    
    res.status(200).json({ msg: 'Form data deleted successfully' });
  } catch (error) {
    console.error('Error deleting form data:', error);
    res.status(500).json({ msg: 'Failed to delete form data' });
  }
});
// Add this to your server.js file

// Forgot Password Route - sends OTP
app.post('/api/auth/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    
    // Check if user exists
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ msg: 'User not found with this email' });
    }
    
    // Generate OTP
    const otp = generateOTP();
    
    // Generate temporary token for password reset
    const tempToken = crypto.randomBytes(20).toString('hex');
    
    // Store OTP and user info temporarily
    otpStore.set(tempToken, {
      userId: user._id,
      email,
      otp,
      createdAt: Date.now() // For OTP expiration
    });
    
    // Send OTP via email
    await transporter.sendMail({
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Password Reset OTP',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 5px;">
          <h2 style="color: #673ab7;">Reset Your Password</h2>
          <p>You requested to reset your password. Please use the following verification code:</p>
          <div style="background-color: #f2f2f2; padding: 10px; text-align: center; font-size: 24px; letter-spacing: 5px; margin: 20px 0; border-radius: 5px;">
            <strong>${otp}</strong>
          </div>
          <p>This code will expire in 10 minutes.</p>
          <p>If you didn't request this reset, please ignore this email.</p>
        </div>
      `
    });

    // Return success with temporary token
    res.status(200).json({ 
      msg: 'OTP sent to your email for password reset',
      tempToken 
    });
    
  } catch (err) {
    console.error('Forgot password error:', err.message);
    res.status(500).json({ msg: 'Server error' });
  }
});

// Reset Password with OTP verification
app.post('/api/auth/reset-password', async (req, res) => {
  try {
    const { email, otp, tempToken, newPassword } = req.body;
    
    // Get stored data
    const userData = otpStore.get(tempToken);
    
    if (!userData) {
      return res.status(400).json({ msg: 'Invalid or expired reset session' });
    }
    
    // Check if OTP is valid and not expired (10 minutes)
    const isExpired = Date.now() - userData.createdAt > 10 * 60 * 1000;
    
    if (isExpired) {
      otpStore.delete(tempToken);
      return res.status(400).json({ msg: 'OTP has expired. Please request a new one' });
    }
    
    if (userData.otp !== otp || userData.email !== email) {
      return res.status(400).json({ msg: 'Invalid OTP' });
    }
    
    // Find the user
    const user = await User.findById(userData.userId);
    if (!user) {
      return res.status(404).json({ msg: 'User not found' });
    }
    
    // Hash new password
    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    
    await user.save();
    
    // Remove temp data
    otpStore.delete(tempToken);
    
    res.status(200).json({ msg: 'Password reset successful' });
    
  } catch (err) {
    console.error('Reset password error:', err.message);
    res.status(500).json({ msg: 'Server error' });
  }
});

// 🚀 START SERVER
app.listen(PORT, () => {
  console.log(`🚀 Server is running on port ${PORT}`);
});