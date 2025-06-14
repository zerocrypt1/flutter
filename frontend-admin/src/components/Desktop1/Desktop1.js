import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios'; // Import axios for API requests
import './Desktop1.css';
import form from "../../assets/form.png";
import Directory from "../../assets/Directory.png";
import menu from "../../assets/menu.png";
import profile from "../../assets/profile.png";
import search from "../../assets/search.png";

function Desktop1() {
  const [formData, setFormData] = useState({
    name: '',
    occupation: '',
    phoneNumber: '',
    identityProof: '',
    landmarks: '',
    age: '',
    state: '',
    address: '',
    otpCode: '',
    timming: '',
    altPhoneNumber: '',
    idProofNumber: '',
    blueTicket: false,
    pinCode: '',
    city: ''
  });

  const [otpSent, setOtpSent] = useState(false);
  const [otpVerified, setOtpVerified] = useState(false);
  const [enteredOtp, setEnteredOtp] = useState('');

  // Handle sending OTP
  const handleSendOTP = async () => {
    try {
      const response = await axios.post('http://localhost:5000/send-otp', { phoneNumber: formData.phoneNumber });
      setOtpSent(true); // Show OTP input form
      console.log('OTP sent successfully:', response.data.message);
    } catch (error) {
      console.error('Error sending OTP:', error);
    }
  };

  // Handle OTP verification
  const handleVerifyOTP = async () => {
    console.log('Verify OTP button clicked'); 
    const requestData = {
      phoneNumber: formData.phoneNumber,
      enteredOtp,
    };
    console.log('Request Data:',requestData); // Log request data
    try {
      const response = await axios.post('http://localhost:5000/verify-otp',requestData);
      if (response.data.message === 'OTP verified successfully') {
        setOtpVerified(true); // Enable Save button
        console.log('OTP verified successfully');
        alert('OTP verified successfully');  // Alert after successful verification
      } else {
        console.error('Invalid OTP');
      }
    } catch (error) {
      console.error('Error verifying OTP:', error.response ? error.response.data : error.message);
      alert('Failed to verify OTP');
    }
  };

  // Handle form input changes
  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData({
      ...formData,
      [name]: type === 'checkbox' ? checked : value
    });
  };

  // Handle form submission
  const handleSubmit = async (e) => {
    e.preventDefault();
    console.log('Submitting formData:', formData);
    try {
      const response = await axios.post('http://localhost:5000/forms', formData);
      console.log('Form submitted successfully:', response.data);
      alert('Information stored successfully!')
    } catch (error) {
      console.error('Error submitting form:', error);
    }
  };

  return (
    <div className="desktop1-container">
      <aside className="desktop1-sidebar">
        <div className="desktop1-sidebar-item">
          <Link to="/desktop2">
            <img src={Directory} alt="Directory" />
            <span>Directory</span>
          </Link>
        </div>
        <div className="desktop1-sidebar-item">
          <Link to="/desktop1">
            <img src={form} alt="Forms" />
            <span>Form</span>
          </Link>
        </div>
      </aside>

      <div className="desktop1-main-content">
        <header className="desktop1-topbar">
          <img src={menu} alt="Menu" className="desktop1-hamburger-icon" />
          <div className="desktop1-profile-icon">
            <img src={profile} alt="Profile" />
          </div>
        </header>

        <div className="desktop1-form-section">
          <form className="desktop1-user-form" onSubmit={handleSubmit}>
            <div className="desktop1-left-column">
              <div className="desktop1-form-group">
                <label>Name <span className="desktop1-required">*</span></label>
                <input type="text" name="name" value={formData.name} onChange={handleChange} placeholder="Enter Name" required />
              </div>

              <div className="desktop1-form-group">
                <label>Occupation <span className="desktop1-required">*</span></label>
                <input type="text" name="occupation" value={formData.occupation} onChange={handleChange} placeholder="Enter Occupation" required />
              </div>

              <div className="desktop1-form-group">
                <label>Phone Number <span className="desktop1-required">*</span></label>
                <input type="text" name="phoneNumber" value={formData.phoneNumber} onChange={handleChange} placeholder="Enter Phone number" required />
              </div>

              <div className="desktop1-form-group">
                <label>Identity Proof</label>
                <input type="text" name="identityProof" value={formData.identityProof} onChange={handleChange} placeholder="Aadhar Card/Pan Card/ Voter ID Card" />
              </div>

              <div className="desktop1-form-group desktop1-landmark-group">
                <label>Landmarks</label>
                <div className="desktop1-landmark-group">
                  <input type="text" name="landmarks" value={formData.landmarks} onChange={handleChange} placeholder="Search landmarks employees want to work in" />
                  <img src={search} alt="Search" className="desktop1-search-icon" />
                </div>
              </div>

              <div className="desktop1-form-group">
                <label>Age <span className="desktop1-required">*</span></label>
                <input type="number" name="age" value={formData.age} onChange={handleChange} placeholder="Enter employee age" required />
              </div>

              <div className="desktop1-form-group">
                <label>State</label>
                <input type="text" name="state" value={formData.state} onChange={handleChange} placeholder="Enter state" />
              </div>

              <div className="desktop1-form-group">
                <label>Address</label>
                <input type="text" name="address" value={formData.address} onChange={handleChange} placeholder="Enter address" />
              </div>

              <div className="desktop1-form-group">
                <label>OTP Code</label>
                <input type="text" name="otpCode" value={enteredOtp} onChange={(e) => setEnteredOtp(e.target.value)} placeholder="Enter OTP code" />
                <button type="button" onClick={handleVerifyOTP} disabled={!otpSent}>Verify OTP</button>
              </div>

              <div className="desktop1-form-group">
                <label>Timming <span className="desktop1-required">*</span></label>
                <input type="number" name="timming" value={formData.timming} onChange={handleChange} placeholder="Enter Timming Maximum is 5" required />
              </div>
            </div>

            <div className="desktop1-right-column">
              <div className="desktop1-form-group">
                <label>Alternative Phone Number</label>
                <input type="text" name="altPhoneNumber" value={formData.altPhoneNumber} onChange={handleChange} placeholder="Enter Alternative Phone number" />
              </div>

              <div className="desktop1-form-group">
                <label>Identity Proof Number</label>
                <input type="text" name="idProofNumber" value={formData.idProofNumber} onChange={handleChange} placeholder="Enter Identity Proof number" />
              </div>

              <div className="desktop1-form-group">
                <label>Blue Tick</label>
                <label className="desktop1-toggle-switch">
                  <input type="checkbox" name="blueTicket" checked={formData.blueTicket} onChange={handleChange} disabled={!otpVerified} />
                  <span className="desktop1-slider"></span>
                </label>
              </div>

              <div className="desktop1-form-group">
                <label>Pin Code</label>
                <input type="text" name="pinCode" value={formData.pinCode} onChange={handleChange} placeholder="Enter pin code" />
              </div>

              <div className="desktop1-form-group">
                <label>City</label>
                <input type="text" name="city" value={formData.city} onChange={handleChange} placeholder="Enter city" />
              </div>
            </div>

            <div className="desktop1-form-row desktop1-form-buttons">
              <button type="button" onClick={handleSendOTP} className="desktop1-send-otp-btn" disabled={otpSent}>Send OTP</button>
              <button type="submit" className="desktop1-save-btn" disabled={!otpVerified}>Save</button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}

export default Desktop1;